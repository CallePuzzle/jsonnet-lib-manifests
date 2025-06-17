local k = import 'k.libsonnet';
local container = k.core.v1.container;
local port = k.core.v1.containerPort;
local volumeMount = k.core.v1.volumeMount;

{
  values:: {
    name: error 'name not set',
    image: error 'image not set',
    tag: 'latest',
    pullPolicy: 'IfNotPresent',
    args: null,
    port: error 'port not set',
    portName: 'http',
    env: {},
    envFrom: [],
    command: null,
    readinessProbe: null,
    livenessProbe: null,
    startupProbe: null,
    requestCpu: null,
    requestMemory: null,
    // Se añade un theshold en la memoria porque este valor típicamente también se usa como límite de la aplicación y hay que tener un margen para el resto de procesos del contenedor
    requestMemoryThr: 1.1,  //110%
    limitCpu: null,
    limitMemory: self.requestMemory,
    limitMemoryThr: 1.2,  //120%
    userId: null,
    volumes: [],
    /* campos que puede tener el objecto volumes
    {
      name: error 'name not set',
      mountPath: error 'mountPath not set',
    }
    */
    containerMixin: {},
  },

  local _cpu(cpu) = if cpu != null then { cpu: cpu } else {},
  local _memory(memory, memoryThr) = if memory != null then { memory: std.round(memory * memoryThr) + 'Mi' } else {},
  local resource(cpu, memory, memoryThr) = _cpu(cpu) + _memory(memory, memoryThr),

  local securityContext = if $.values.userId != null then
    container.securityContext.withRunAsUser($.values.userId)
  else {},

  local args = if $.values.args != null then
    container.withArgs($.values.args)
  else {},
  local command = if $.values.command != null then
    container.withCommand($.values.command)
  else {},

  local _port = if $.values.port != null then container.withPorts([port.newNamed($.values.port, $.values.portName)]) else {},

  local _volumeMount(fields) = volumeMount.withName(fields.name)
                               + volumeMount.withMountPath(fields.mountPath)
                               + if std.objectHas(fields, 'subPath') then volumeMount.withSubPath(fields.subPath) else {},
  local volumes = if std.length($.values.volumes) > 0 then
    container.withVolumeMountsMixin([_volumeMount(volume) for volume in $.values.volumes]) else {},

  this: container.new($.values.name, $.values.image + ':' + $.values.tag)
        + _port
        + container.resources.withLimits(resource($.values.limitCpu, $.values.limitMemory, $.values.limitMemoryThr))
        + container.resources.withRequests(resource($.values.requestCpu, $.values.requestMemory, $.values.requestMemoryThr))
        //+ container.securityContext.withPrivileged(false)
        + securityContext
        + { readinessProbe: $.values.readinessProbe }
        + { livenessProbe: $.values.livenessProbe }
        + { startupProbe: $.values.startupProbe }
        + container.withImagePullPolicy($.values.pullPolicy)
        + container.withEnvMap($.values.env)
        + container.withEnvFrom($.values.envFrom)
        + command
        + args
        + volumes
        + $.values.containerMixin,
}
