class OverlayStatus {
  const OverlayStatus({
    required this.hasPermission,
    required this.serviceRunning,
  });

  final bool hasPermission;
  final bool serviceRunning;

  OverlayStatus copyWith({
    bool? hasPermission,
    bool? serviceRunning,
  }) {
    return OverlayStatus(
      hasPermission: hasPermission ?? this.hasPermission,
      serviceRunning: serviceRunning ?? this.serviceRunning,
    );
  }
}
