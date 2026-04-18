/// The kind of content carried by a [ChatMessage].
enum MessageType {
  /// A normal user-typed message.
  text,

  /// An automated message injected by the system (e.g. "Project started",
  /// "Dispute raised"). Rendered centred and in a muted style.
  system;

  static MessageType fromString(String v) =>
      MessageType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => MessageType.text,
      );
}
