enum NodeRole {
  Normal,
  Relay,
  Bridge,
  Emergency,
}

class Node {
  final String nodeId;
  String username;
  NodeRole nodeRole;
  int batteryLevel;
  int signalStrength;
  DateTime lastSeen;

  Node({
    required this.nodeId,
    required this.username,
    this.nodeRole = NodeRole.Normal,
    this.batteryLevel = 100,
    this.signalStrength = 0,
    required this.lastSeen,
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      nodeId: json['nodeId'],
      username: json['username'],
      nodeRole: NodeRole.values[json['nodeRole']],
      batteryLevel: json['batteryLevel'],
      signalStrength: json['signalStrength'],
      lastSeen: DateTime.fromMillisecondsSinceEpoch(json['lastSeen']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'username': username,
      'nodeRole': nodeRole.index,
      'batteryLevel': batteryLevel,
      'signalStrength': signalStrength,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
    };
  }
}
