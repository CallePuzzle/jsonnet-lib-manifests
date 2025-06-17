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
    port: null,
    portName: 'http',
    env: {},
    envFrom: [],
    command: null,
    readinessProbe: null,
    livenessProbe: null,
    startupProbe: null,
    requestCpu: error 'requestCpu not set',
    requestMemory: error 'requestMemory not set',
    limitCpu: null,
    limitMemory: self.requestMemory,
    userId: error 'userId not set',
    containerMixin: {},
  },

  local _cpu(cpu) = if cpu != null then { cpu: cpu } else {},
  local _memory(memory) = if memory != null then { memory: memory } else {},
  local resource(cpu, memory) = _cpu(cpu) + _memory(memory),

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

  this: container.new($.values.name, $.values.image + ':' + $.values.tag)
        + _port
        + container.resources.withLimits(resource($.values.limitCpu, $.values.limitMemory))
        + container.resources.withRequests(resource($.values.requestCpu, $.values.requestMemory))
        + securityContext
        + { readinessProbe: $.values.readinessProbe }
        + { livenessProbe: $.values.livenessProbe }
        + { startupProbe: $.values.startupProbe }
        + container.withImagePullPolicy($.values.pullPolicy)
        + container.withEnvMap($.values.env)
        + container.withEnvFrom($.values.envFrom)
        + command
        + args
        + $.values.containerMixin,
}
