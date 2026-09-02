local secret = (import '../../secret-stringData.libsonnet');

local defaultWave = secret {
  values+:: {
    name: 'default-wave',
    namespace: 'default',
    stringData: {
      username: 'admin',
      password: 'change-me',
    },
  },
};

local customWave = secret {
  values+:: {
    name: 'custom-wave',
    namespace: 'default',
    syncWave: '99',
    stringData: {
      token: 'placeholder',
    },
  },
};

assert defaultWave.secret.metadata.annotations['argocd.argoproj.io/sync-wave'] == '10' : 'default sync-wave mismatch';
assert customWave.secret.metadata.annotations['argocd.argoproj.io/sync-wave'] == '99' : 'custom sync-wave mismatch';

{
  default_wave: defaultWave,
  custom_wave: customWave,
}
