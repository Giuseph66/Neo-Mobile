#include <jni.h>
#include <string>
#include <cstring>
#include <vector>
#include <mutex>
#include <atomic>
#include <chrono>
#include "llama.h"

namespace {
    std::mutex g_mutex;
    std::atomic_bool g_abort{false};
    bool g_backend_init = false;
    llama_model * g_model = nullptr;
    llama_context * g_ctx = nullptr;
    llama_sampler * g_sampler = nullptr;
    const llama_vocab * g_vocab = nullptr;
    int g_max_tokens = 0;
    int g_generated = 0;
    bool g_generating = false;
    int g_threads = 4;
    int g_threads_batch = 4;
    double g_last_tps = 0.0;
    std::chrono::steady_clock::time_point g_start_time;

    bool abort_callback(void * data) {
        auto * flag = static_cast<std::atomic_bool *>(data);
        return flag && flag->load();
    }

    void free_model_locked() {
        if (g_sampler) {
            llama_sampler_free(g_sampler);
            g_sampler = nullptr;
        }
        g_vocab = nullptr;
        g_generating = false;
        g_max_tokens = 0;
        g_generated = 0;
        if (g_ctx) {
            llama_free(g_ctx);
            g_ctx = nullptr;
        }
        if (g_model) {
            llama_model_free(g_model);
            g_model = nullptr;
        }
    }
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_neo_llm_LocalLlmEngine_nativeInit(JNIEnv *, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!g_backend_init) {
        llama_backend_init();
        g_backend_init = true;
    }
    return JNI_TRUE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_neo_llm_LocalLlmEngine_nativeLoadModel(JNIEnv * env, jobject, jstring path, jint ctxLen, jint threads) {
    std::lock_guard<std::mutex> lock(g_mutex);
    free_model_locked();
    g_abort.store(false);

    const char * pathChars = env->GetStringUTFChars(path, nullptr);
    llama_model_params mparams = llama_model_default_params();
    mparams.n_gpu_layers = 0;

    g_model = llama_model_load_from_file(pathChars, mparams);
    env->ReleaseStringUTFChars(path, pathChars);

    if (!g_model) {
        return JNI_FALSE;
    }

    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx = ctxLen > 0 ? static_cast<uint32_t>(ctxLen) : 2048;
    cparams.n_batch = std::min<uint32_t>(512, cparams.n_ctx);
    g_threads = threads > 0 ? threads : 4;
    g_threads_batch = threads > 0 ? threads : 4;
    cparams.n_threads = g_threads;
    cparams.n_threads_batch = g_threads_batch;

    g_ctx = llama_init_from_model(g_model, cparams);
    if (!g_ctx) {
        llama_model_free(g_model);
        g_model = nullptr;
        return JNI_FALSE;
    }

    llama_set_n_threads(g_ctx, g_threads, g_threads_batch);
    llama_set_abort_callback(g_ctx, abort_callback, &g_abort);
    llama_memory_clear(llama_get_memory(g_ctx), true);

    return JNI_TRUE;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_neo_llm_LocalLlmEngine_nativeUnload(JNIEnv *, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_abort.store(true);
    free_model_locked();
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_neo_llm_LocalLlmEngine_nativeGenerate(
        JNIEnv *env,
        jobject,
        jstring prompt,
        jdouble temp,
        jdouble topP,
        jint topK,
        jint maxTokens) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!g_ctx || !g_model) {
        return env->NewStringUTF("Erro: modelo nao carregado.");
    }

    g_abort.store(false);
    llama_memory_clear(llama_get_memory(g_ctx), true);

    const char * promptChars = env->GetStringUTFChars(prompt, nullptr);
    std::string promptStr = promptChars ? promptChars : "";
    env->ReleaseStringUTFChars(prompt, promptChars);

    const auto * vocab = llama_model_get_vocab(g_model);

    const int n_ctx = static_cast<int>(llama_n_ctx(g_ctx));
    std::vector<llama_token> tokens(n_ctx);
    int n_prompt = llama_tokenize(
        vocab,
        promptStr.c_str(),
        static_cast<int>(promptStr.size()),
        tokens.data(),
        static_cast<int>(tokens.size()),
        true,
        true
    );

    if (n_prompt < 0) {
        const int required = -n_prompt;
        if (required > n_ctx) {
            return env->NewStringUTF("Erro: prompt excede o contexto.");
        }
        tokens.resize(required);
        n_prompt = llama_tokenize(
            vocab,
            promptStr.c_str(),
            static_cast<int>(promptStr.size()),
            tokens.data(),
            static_cast<int>(tokens.size()),
            true,
            true
        );
    }

    if (n_prompt <= 0) {
        return env->NewStringUTF("Erro: tokenizacao falhou.");
    }
    tokens.resize(n_prompt);

    llama_batch batch = llama_batch_get_one(tokens.data(), tokens.size());
    if (llama_decode(g_ctx, batch) != 0) {
        return env->NewStringUTF("Erro: falha ao processar prompt.");
    }

    const int tk = topK > 0 ? topK : 40;
    const double tp = topP > 0.0 ? topP : 0.9;
    const double t = temp > 0.0 ? temp : 0.7;

    auto sparams = llama_sampler_chain_default_params();
    llama_sampler * sampler = llama_sampler_chain_init(sparams);
    llama_sampler_chain_add(sampler, llama_sampler_init_top_k(tk));
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(tp, 1));
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(t));
    llama_sampler_chain_add(
        sampler,
        llama_sampler_init_dist(static_cast<uint32_t>(
            std::chrono::high_resolution_clock::now().time_since_epoch().count()))
    );

    std::string output;
    for (int i = 0; i < maxTokens; ++i) {
        if (g_abort.load()) {
            break;
        }
        llama_token new_token = llama_sampler_sample(sampler, g_ctx, -1);
        llama_sampler_accept(sampler, new_token);
        if (llama_vocab_is_eog(vocab, new_token)) {
            break;
        }
        char buf[256];
        int n = llama_token_to_piece(vocab, new_token, buf, sizeof(buf), 0, true);
        if (n > 0) {
            output.append(buf, n);
        }
        batch = llama_batch_get_one(&new_token, 1);
        if (llama_decode(g_ctx, batch) != 0) {
            break;
        }
    }

    llama_sampler_free(sampler);
    return env->NewStringUTF(output.c_str());
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_neo_llm_LocalLlmEngine_nativeGenerateStart(
        JNIEnv *env,
        jobject,
        jstring prompt,
        jdouble temp,
        jdouble topP,
        jint topK,
        jint maxTokens) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!g_ctx || !g_model) {
        return JNI_FALSE;
    }

    g_abort.store(false);
    g_generating = false;
    g_generated = 0;
    g_max_tokens = maxTokens > 0 ? maxTokens : 256;
    g_last_tps = 0.0;
    g_start_time = std::chrono::steady_clock::now();

    if (g_sampler) {
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
    }

    llama_memory_clear(llama_get_memory(g_ctx), true);
    llama_set_n_threads(g_ctx, g_threads, g_threads_batch);

    const char * promptChars = env->GetStringUTFChars(prompt, nullptr);
    std::string promptStr = promptChars ? promptChars : "";
    env->ReleaseStringUTFChars(prompt, promptChars);

    g_vocab = llama_model_get_vocab(g_model);
    if (!g_vocab) {
        return JNI_FALSE;
    }

    const int n_ctx = static_cast<int>(llama_n_ctx(g_ctx));
    std::string promptFormatted = promptStr;
    const char * tmpl = llama_model_chat_template(g_model, nullptr);
    if (tmpl) {
        llama_chat_message chat[1];
        chat[0].role = "user";
        chat[0].content = promptStr.c_str();
        int32_t buf_len = static_cast<int32_t>(promptStr.size() * 2 + 256);
        std::vector<char> buf(buf_len);
        int32_t res = llama_chat_apply_template(tmpl, chat, 1, true, buf.data(), buf_len);
        if (res > 0) {
            if (res >= buf_len) {
                buf.resize(res + 1);
                res = llama_chat_apply_template(tmpl, chat, 1, true, buf.data(), static_cast<int32_t>(buf.size()));
            }
            if (res > 0) {
                promptFormatted.assign(buf.data(), res);
            }
        }
    }

    std::vector<llama_token> tokens(n_ctx);
    int n_prompt = llama_tokenize(
        g_vocab,
        promptFormatted.c_str(),
        static_cast<int>(promptFormatted.size()),
        tokens.data(),
        static_cast<int>(tokens.size()),
        true,
        true
    );

    if (n_prompt < 0) {
        const int required = -n_prompt;
        if (required > n_ctx) {
            return JNI_FALSE;
        }
        tokens.resize(required);
        n_prompt = llama_tokenize(
            g_vocab,
            promptFormatted.c_str(),
            static_cast<int>(promptFormatted.size()),
            tokens.data(),
            static_cast<int>(tokens.size()),
            true,
            true
        );
    }

    if (n_prompt <= 0) {
        return JNI_FALSE;
    }

    tokens.resize(n_prompt);
    llama_batch batch = llama_batch_get_one(tokens.data(), tokens.size());
    if (llama_decode(g_ctx, batch) != 0) {
        return JNI_FALSE;
    }

    const int tk = topK > 0 ? topK : 40;
    const double tp = topP > 0.0 ? topP : 0.9;
    const double t = temp > 0.0 ? temp : 0.7;

    auto sparams = llama_sampler_chain_default_params();
    g_sampler = llama_sampler_chain_init(sparams);
    llama_sampler_chain_add(g_sampler, llama_sampler_init_top_k(tk));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_top_p(tp, 1));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_temp(t));
    llama_sampler_chain_add(
        g_sampler,
        llama_sampler_init_dist(static_cast<uint32_t>(
            std::chrono::high_resolution_clock::now().time_since_epoch().count()))
    );

    g_generating = true;
    return JNI_TRUE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_neo_llm_LocalLlmEngine_nativeGenerateNext(JNIEnv *env, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!g_generating || !g_ctx || !g_sampler || !g_vocab) {
        return env->NewStringUTF("");
    }
    if (g_abort.load() || g_generated >= g_max_tokens) {
        g_generating = false;
        if (g_sampler) {
            llama_sampler_free(g_sampler);
            g_sampler = nullptr;
        }
        return env->NewStringUTF("");
    }

    llama_token new_token = llama_sampler_sample(g_sampler, g_ctx, -1);
    llama_sampler_accept(g_sampler, new_token);
    if (llama_vocab_is_eog(g_vocab, new_token)) {
        g_generating = false;
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
        return env->NewStringUTF("");
    }

    char buf[256];
    int n = llama_token_to_piece(g_vocab, new_token, buf, sizeof(buf), 0, true);
    if (n <= 0) {
        return env->NewStringUTF("");
    }

    llama_batch batch = llama_batch_get_one(&new_token, 1);
    if (llama_decode(g_ctx, batch) != 0) {
        g_generating = false;
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
        return env->NewStringUTF("");
    }

    g_generated += 1;
    const auto now = std::chrono::steady_clock::now();
    const double elapsed =
        std::chrono::duration_cast<std::chrono::duration<double>>(now - g_start_time).count();
    if (elapsed > 0.0) {
        g_last_tps = g_generated / elapsed;
    }
    return env->NewStringUTF(std::string(buf, n).c_str());
}

extern "C" JNIEXPORT jdouble JNICALL
Java_com_example_neo_llm_LocalLlmEngine_nativeGetLastTps(JNIEnv *, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    return g_last_tps;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_neo_llm_LocalLlmEngine_nativeStop(JNIEnv *, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_abort.store(true);
    g_generating = false;
    if (g_sampler) {
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
    }
}
