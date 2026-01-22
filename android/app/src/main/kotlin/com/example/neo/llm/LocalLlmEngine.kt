package com.example.neo.llm

import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

class LocalLlmEngine {
    private var nativeReady = false
    private val stopFlag = AtomicBoolean(false)
    private var lastTps = 0.0

    init {
        nativeReady = try {
            System.loadLibrary("llama_jni")
            nativeInit()
        } catch (e: UnsatisfiedLinkError) {
            false
        }
    }

    fun isNativeReady(): Boolean = nativeReady

    fun loadModel(path: String, ctxLen: Int, threads: Int): Boolean {
        stopFlag.set(false)
        return if (nativeReady) {
            nativeLoadModel(path, ctxLen, threads)
        } else {
            false
        }
    }

    fun unload() {
        stopFlag.set(true)
        if (nativeReady) {
            nativeUnload()
        }
    }

    fun generate(
        prompt: String,
        temp: Double,
        topP: Double,
        topK: Int,
        maxTokens: Int,
        onToken: (String) -> Unit,
        onDone: () -> Unit,
        onError: (String) -> Unit
    ) {
        stopFlag.set(false)
        Thread {
            try {
                if (!nativeReady) {
                    onError("JNI stub ativo. Integre o llama.cpp para gerar resposta real.")
                    return@Thread
                }
                val started = nativeGenerateStart(prompt, temp, topP, topK, maxTokens)
                if (!started) {
                    onError("Falha ao iniciar geracao.")
                    return@Thread
                }
                while (!stopFlag.get()) {
                    val token = nativeGenerateNext()
                    if (token.isNullOrEmpty()) {
                        break
                    }
                    lastTps = nativeGetLastTps()
                    onToken(token)
                }
                if (!stopFlag.get()) {
                    onDone()
                }
            } catch (e: Exception) {
                onError(e.message ?: "Erro na geracao")
            }
        }.start()
    }

    fun stop() {
        stopFlag.set(true)
        if (nativeReady) {
            nativeStop()
        }
    }

    fun getLastTps(): Double = lastTps

    private external fun nativeInit(): Boolean
    private external fun nativeLoadModel(path: String, ctxLen: Int, threads: Int): Boolean
    private external fun nativeUnload()
    private external fun nativeGenerate(
        prompt: String,
        temp: Double,
        topP: Double,
        topK: Int,
        maxTokens: Int
    ): String
    private external fun nativeGenerateStart(
        prompt: String,
        temp: Double,
        topP: Double,
        topK: Int,
        maxTokens: Int
    ): Boolean
    private external fun nativeGenerateNext(): String?
    private external fun nativeGetLastTps(): Double
    private external fun nativeStop()
}
