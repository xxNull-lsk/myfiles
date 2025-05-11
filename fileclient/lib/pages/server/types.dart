class ServerOs {
  DateTime bootTime = DateTime.now();
  String platform = "";
  String family = "";
  String version = "";
  String kernelVersion = "";
  String kernelArch = "";
  String virtualizationSystem = "";
  String virtualizationRole = "";
  ServerOs.fromMap(Map map) {
    bootTime = DateTime.parse(map["boot_time"] ?? "1970-01-01 00:00:00");
    platform = map["platform"] ?? "";
    family = map["family"] ?? "";
    version = map["version"] ?? "";
    kernelVersion = map["kernel_version"] ?? "";
    kernelArch = map["kernel_arch"] ?? "";
    virtualizationRole = map["virtualization_role"] ?? "";
    virtualizationSystem = map["virtualization_system"] ?? "";
  }
}

class CpuBaseInfo {
  final int cpu;
  final String vendorId;
  final String family;
  final String model;
  final int stepping;
  final String physicalId;
  final String coreId;
  final int cores;
  final String modelName;
  final double mhz;
  final int cacheSize;
  final List<String> flags;
  final String microcode;

  CpuBaseInfo({
    required this.cpu,
    required this.vendorId,
    required this.family,
    required this.model,
    required this.stepping,
    required this.physicalId,
    required this.coreId,
    required this.cores,
    required this.modelName,
    required this.mhz,
    required this.cacheSize,
    required this.flags,
    required this.microcode,
  });

  // 将对象转换为 Map，方便进行 JSON 序列化
  Map<String, dynamic> toJson() {
    return {
      'cpu': cpu,
      'vendorId': vendorId,
      'family': family,
      'model': model,
      'stepping': stepping,
      'physicalId': physicalId,
      'coreId': coreId,
      'cores': cores,
      'modelName': modelName,
      'mhz': mhz,
      'cacheSize': cacheSize,
      'flags': flags,
      'microcode': microcode,
    };
  }

  // 从 Map 创建对象，方便进行 JSON 反序列化
  factory CpuBaseInfo.fromJson(Map<String, dynamic> json) {
    return CpuBaseInfo(
      cpu: json['cpu'] ?? 0,
      vendorId: json['vendorId'] ?? '',
      family: json['family'] ?? '',
      model: json['model'] ?? '',
      stepping: json['stepping'] ?? 0,
      physicalId: json['physicalId'] ?? '',
      coreId: json['coreId'] ?? '',
      cores: json['cores'] ?? 0,
      modelName: json['modelName'] ?? '',
      mhz: json['mhz']?.toDouble() ?? 0.0,
      cacheSize: json['cacheSize'] ?? 0,
      flags: List<String>.from(json['flags'] ?? []),
      microcode: json['microcode'] ?? '',
    );
  }
}

class CpuStatus {
  List<double> totalPercent;
  List<double> perPercents;
  int temperature;
  List<int> preTemperatures;

  CpuStatus({
    required this.totalPercent,
    required this.perPercents,
    required this.temperature,
    required this.preTemperatures,
  });

  // 将对象转换为 Map，方便进行 JSON 序列化
  Map<String, dynamic> toJson() {
    return {
      'TotalPercent': totalPercent,
      'PerPercents': perPercents,
      'Temperature': temperature,
      'PreTemperatures': preTemperatures,
    };
  }

  // 从 Map 创建对象，方便进行 JSON 反序列化
  factory CpuStatus.fromJson(Map<String, dynamic> json) {
    List<double> totalPercent = [];
    List<double> perPercents = [];
    List<int> preTemperatures = [];
    if (json['TotalPercent'] != null) {
      for (var element in json['TotalPercent']) {
        totalPercent.add(double.parse(element.toString()));
      }
    }
    if (json['PerPercents'] != null) {
      for (var element in json['PerPercents']) {
        perPercents.add(double.parse(element.toString()));
      }
    }
    if (json['PreTemperatures'] != null) {
      for (var element in json['PreTemperatures']) {
        preTemperatures.add(int.parse(element.toString()));
      }
    }
    return CpuStatus(
      totalPercent: totalPercent,
      perPercents: perPercents,
      temperature: int.parse(json['Temperature']?.toString() ?? "0"),
      preTemperatures: preTemperatures,
    );
  }
}

class CpuStateInfo {
  DateTime time;
  CpuStatus stat;

  CpuStateInfo({
    required this.time,
    required this.stat,
  });

  // 将对象转换为 Map，方便进行 JSON 序列化
  Map<String, dynamic> toJson() {
    return {
      'time': time.toIso8601String(),
      'stat': stat.toJson(),
    };
  }

  // 从 Map 创建对象，方便进行 JSON 反序列化
  factory CpuStateInfo.fromJson(Map<String, dynamic> json) {
    return CpuStateInfo(
      time: DateTime.parse(json['time']),
      stat: CpuStatus.fromJson(json['stat']),
    );
  }
}

class ServerCpu {
  int physicalCount = 0;
  int logicalCount = 0;
  List<CpuStateInfo> cpuStateInfo = [];
  List<CpuBaseInfo> cpuInfos = [];
  ServerCpu.fromMap(Map map) {
    physicalCount = map["physical_count"] ?? 0;
    logicalCount = map["logical_count"] ?? 0;
    cpuStateInfo.clear();
    if (map["status"] != null) {
      for (var element in map["status"]) {
        cpuStateInfo.add(CpuStateInfo.fromJson(element));
      }
    }
    cpuInfos.clear();
    if (map["info"] != null) {
      for (var element in map["info"]) {
        cpuInfos.add(CpuBaseInfo.fromJson(element));
      }
    }
  }
}

class ServerNetWork {
  Map<String, ServerInterface> interfaces = {};
  Map<String, ServerNetCounter> counters = {};
  ServerNetWork.fromMap(Map json) {
    interfaces.clear();
    if (json["interfaces"] != null) {
      for (var element in (json["interfaces"] as Map).values) {
        interfaces[element["name"] ?? ""] = ServerInterface.fromMap(element);
      }
    }
    counters.clear();
    if (json["counters"] != null) {
      for (var element in json["counters"]) {
        counters[element["name"]] = ServerNetCounter.fromMap(element);
      }
    }
  }
}

class ServerInterface {
  int index = 0;
  int mtu = 0;
  String name = "";
  String hardwareaddr = "";
  List<String> flags = [];
  List<String> addrs = [];
  List<double> speedSend = [];
  List<double> speedRecv = [];

  ServerInterface.fromMap(Map map) {
    index = map["index"] ?? 0;
    mtu = map["mtu"] ?? 0;
    name = map["name"] ?? "";
    hardwareaddr = map["hardwareaddr"] ?? "";
    flags = List.from(map["flags"] ?? []);
    addrs.clear();
    if (map["addrs"] != null) {
      for (var element in map["addrs"]) {
        addrs.add(element["addr"] ?? "");
      }
    }
    speedSend.clear();
    speedRecv.clear();
    if (map["speed_send"] != null) {
      for (var element in map["speed_send"]) {
        speedSend.add(double.parse(element.toString()));
      }
    }
    if (map["speed_recv"] != null) {
      for (var element in map["speed_recv"]) {
        speedRecv.add(double.parse(element.toString()));
      }
    }
  }
}

class ServerNetCounter {
  String name = "";
  int bytesSent = 0;
  int bytesRecv = 0;
  int packetsSent = 0;
  int packetsRecv = 0;
  int errin = 0;
  int errout = 0;
  int dropin = 0;
  int dropout = 0;
  int fifoin = 0;
  int fifoout = 0;

  ServerNetCounter.fromMap(Map map) {
    name = map["name"] ?? "";
    bytesSent = map["bytesSent"] ?? 0;
    bytesRecv = map["bytesRecv"] ?? 0;
    packetsSent = map["packetsSent"] ?? 0;
    packetsRecv = map["packetsRecv"] ?? 0;
    errin = map["errin"] ?? 0;
    errout = map["errout"] ?? 0;
    dropin = map["dropin"] ?? 0;
    dropout = map["dropout"] ?? 0;
    fifoin = map["fifoin"] ?? 0;
    fifoout = map["fifoout"] ?? 0;
  }
}

class MemoryStateInfo {
  DateTime time;
  ServerMemory stat;

  MemoryStateInfo({
    required this.time,
    required this.stat,
  });

  // 将对象转换为 Map，方便进行 JSON 序列化
  Map<String, dynamic> toJson() {
    return {
      'time': time.toIso8601String(),
      'stat': stat.toJson(),
    };
  }

  // 从 Map 创建对象，方便进行 JSON 反序列化
  factory MemoryStateInfo.fromJson(Map<String, dynamic> json) {
    return MemoryStateInfo(
      time: DateTime.parse(json['time']),
      stat: ServerMemory.fromMap(json['stat']),
    );
  }
}

class ServerMemory {
  int total = 1;
  int available = 0;
  int swaptotal = 1;
  int swapused = 0;
  int used = 0;
  int free = 0;
  ServerMemory.fromMap(Map map) {
    total = map["total"] ?? 1;
    available = map["available"] ?? 0;
    swaptotal = map["swaptotal"] ?? 1;
    int swapfree = map["swapfree"] ?? 0;
    swapused = swaptotal - swapfree;
    used = map["used"] ?? 0;
    free = map["free"] ?? 0;
  }
  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'available': available,
      'swaptotal': swaptotal,
      'swapused': swapused,
      'used': used,
      'free': free,
    };
  }
}

class PartitionInfo {
  String path;
  String fstype;
  int total;
  int used;
  int free;
  double usedPercent;
  PartitionInfo({
    required this.path,
    required this.fstype,
    required this.total,
    required this.used,
    required this.free,
    required this.usedPercent,
  });
  // 从 JSON 数据创建 PartitionInfo 实例
  factory PartitionInfo.fromJson(Map<String, dynamic> json) {
    return PartitionInfo(
      path: json['path'],
      fstype: json['fstype'] ?? "",
      total: json['total'] ?? 0,
      used: json['used'] ?? 0,
      free: json['free'] ?? 0,
      usedPercent: json['used_percent'] ?? 0,
    );
  }
  // 将 PartitionInfo 实例转换为 JSON 格式的 Map
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'fstype': fstype,
      'total': total,
      'used': used,
      'free': free,
      'used_percent': usedPercent,
    };
  }
}

class ServerUser {
  String name = "";
  String terminal = "";
  String host = "";
  int started = 0;
  ServerUser.fromMap(Map map) {
    name = map["user"] ?? "";
    terminal = map["terminal"] ?? "";
    host = map["host"] ?? "";
    started = map["started"] ?? 0;
  }
}

class IOCountersStat {
  final int readCount;
  final int mergedReadCount;
  final int writeCount;
  final int mergedWriteCount;
  final int readBytes;
  final int writeBytes;
  final int readTime;
  final int writeTime;
  final int iopsInProgress;
  final int ioTime;
  final int weightedIO;
  final String name;
  final String serialNumber;
  final String label;

  IOCountersStat({
    required this.readCount,
    required this.mergedReadCount,
    required this.writeCount,
    required this.mergedWriteCount,
    required this.readBytes,
    required this.writeBytes,
    required this.readTime,
    required this.writeTime,
    required this.iopsInProgress,
    required this.ioTime,
    required this.weightedIO,
    required this.name,
    required this.serialNumber,
    required this.label,
  });

  // 将对象转换为Map，方便进行JSON序列化
  Map<String, dynamic> toJson() {
    return {
      'readCount': readCount,
      'mergedReadCount': mergedReadCount,
      'writeCount': writeCount,
      'mergedWriteCount': mergedWriteCount,
      'readBytes': readBytes,
      'writeBytes': writeBytes,
      'readTime': readTime,
      'writeTime': writeTime,
      'iopsInProgress': iopsInProgress,
      'ioTime': ioTime,
      'weightedIO': weightedIO,
      'name': name,
      'serialNumber': serialNumber,
      'label': label,
    };
  }

  // 从Map创建对象，方便进行JSON反序列化
  factory IOCountersStat.fromJson(Map<String, dynamic> json) {
    return IOCountersStat(
      readCount: json['readCount'] ?? 0,
      mergedReadCount: json['mergedReadCount'] ?? 0,
      writeCount: json['writeCount'] ?? 0,
      mergedWriteCount: json['mergedWriteCount'] ?? 0,
      readBytes: json['readBytes'] ?? 0,
      writeBytes: json['writeBytes'] ?? 0,
      readTime: json['readTime'] ?? 0,
      writeTime: json['writeTime'] ?? 0,
      iopsInProgress: json['iopsInProgress'] ?? 0,
      ioTime: json['ioTime'] ?? 0,
      weightedIO: json['weightedIO'] ?? 0,
      name: json['name'] ?? "",
      serialNumber: json['serialNumber'] ?? "",
      label: json['label'] ?? "",
    );
  }
}

class BlockBaseInfo {
  List<BlockDevice> blockDevices;

  BlockBaseInfo({
    required this.blockDevices,
  });

  // 从 JSON 数据创建 BlockUsge 实例
  factory BlockBaseInfo.fromJson(Map<String, dynamic> json) {
    List<dynamic> blockDevicesJson = [];
    if (json['blockdevices'] != null) {
      blockDevicesJson = json['blockdevices'] as List<dynamic>;
    }
    List<BlockDevice> blockDevices = blockDevicesJson
        .map((deviceJson) => BlockDevice.fromJson(deviceJson))
        .toList();

    return BlockBaseInfo(
      blockDevices: blockDevices,
    );
  }

  // 将 BlockUsge 实例转换为 JSON 格式的 Map
  Map<String, dynamic> toJson() {
    return {
      'blockdevices': blockDevices.map((device) => device.toJson()).toList(),
    };
  }
}

class BlockStatus {
  double readSpeed;
  double writeSpeed;
  BlockStatus({
    required this.readSpeed,
    required this.writeSpeed,
  });
  // 将对象转换为 Map，方便进行 JSON 序列化
  Map<String, dynamic> toJson() {
    return {
      'read_speed': readSpeed,
      'write_speed': writeSpeed,
    };
  }

  // 从 Map 创建对象，方便进行 JSON 反序列化
  factory BlockStatus.fromJson(Map<String, dynamic> json) {
    return BlockStatus(
      readSpeed: (json['read_speed'] ?? 0).toDouble(),
      writeSpeed: (json['write_speed'] ?? 0).toDouble(),
    );
  }
}

class BlockStateInfo {
  DateTime? time;
  BlockStatus? stat;
  BlockStateInfo({
    this.time,
    this.stat,
  });
  // 将对象转换为 Map，方便进行 JSON 序列化
  Map<String, dynamic> toJson() {
    return {
      'time': time?.toIso8601String(),
      'stat': stat?.toJson(),
    };
  }

  // 从 Map 创建对象，方便进行 JSON 反序列化
  factory BlockStateInfo.fromJson(Map<String, dynamic> json) {
    return BlockStateInfo(
      time: json['time'] != null ? DateTime.parse(json['time']) : null,
      stat: json['stat'] != null ? BlockStatus.fromJson(json['stat']) : null,
    );
  }
}

class BlockDevice {
  String name;
  String? fstype;
  String? fsVer;
  String? label;
  String? uuid;
  int? fsavail;
  String? fsused;
  int? size;
  List<String?> mountpoints;
  List<BlockDevice>? children;
  List<BlockStateInfo>? stateInfo;

  BlockDevice({
    required this.name,
    this.fstype,
    this.fsVer,
    this.label,
    this.uuid,
    this.fsavail,
    this.fsused,
    this.size,
    required this.mountpoints,
    this.children,
    required this.stateInfo,
  });

  // 从 JSON 数据创建 BlockDevice 实例
  factory BlockDevice.fromJson(Map<String, dynamic> json) {
    var mountpointsJson = json['mountpoints'] as List<dynamic>;
    List<String?> mountpoints =
        mountpointsJson.map((point) => point?.toString() ?? "").toList();

    List<BlockDevice>? children;
    if (json['children'] != null) {
      var childrenJson = json['children'] as List<dynamic>;
      children = childrenJson
          .map((childJson) => BlockDevice.fromJson(childJson))
          .toList();
    }
    List<BlockStateInfo> stateInfo = [];
    if (json['state_info'] != null) {
      var stateInfoJson = json['state_info'] as List<dynamic>;
      stateInfo = stateInfoJson
          .map((stateInfo) => BlockStateInfo.fromJson(stateInfo))
          .toList();
    }

    return BlockDevice(
      name: json['name'],
      fstype: json['fstype'],
      fsVer: json['fsver'],
      label: json['label'],
      uuid: json['uuid'],
      fsavail: json['fsavail'],
      fsused: json['fsuse%'],
      size: json['size'],
      mountpoints: mountpoints,
      children: children,
      stateInfo: stateInfo,
    );
  }

  // 将 BlockDevice 实例转换为 JSON 格式的 Map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'fstype': fstype,
      'fsver': fsVer,
      'label': label,
      'uuid': uuid,
      'fsavail': fsavail,
      'fsuse%': fsused,
      'mountpoints': mountpoints,
      'children': children?.map((child) => child.toJson()).toList(),
    };
  }
}

class ServerDisks {
  Map<String, BlockDevice> blocks;
  Map<String, IOCountersStat> counters;
  List<PartitionInfo> partitions;
  ServerDisks({
    required this.blocks,
    required this.counters,
    required this.partitions,
  });
  factory ServerDisks.fromJson(Map<String, dynamic> json) {
    Map<String, IOCountersStat> counters = {};
    if (json['counters'] != null) {
      Map m = json['counters'];
      m.forEach((key, value) {
        counters[key] = IOCountersStat.fromJson(value);
      });
    }
    Map<String, BlockDevice> blocks = {};
    if (json['blocks'] != null) {
      Map m = json['blocks'];
      m.forEach((key, value) {
        blocks[key] = BlockDevice.fromJson(value);
      });
    }
    return ServerDisks(
      blocks: blocks,
      counters: counters,
      partitions: json['partitions'] != null
          ? (json['partitions'] as List<dynamic>)
              .map((partitionJson) => PartitionInfo.fromJson(partitionJson))
              .toList()
          : [],
    );
  }
}
