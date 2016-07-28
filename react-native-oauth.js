/**
 * @providesModule OAuthManager
 * @flow
 */
import {
  NativeModules,
  AsyncStorage
} from 'react-native';
const OAuthManagerBridge = NativeModules.OAuthManager;

let configured = false;
const STORAGE_KEY = 'ReactNativeOAuth';

const promisify = fn => (...args) => {
  return new Promise((resolve, reject) => {
    const handler = (err, resp) => err ? reject(err) : resolve(resp);
    args.push(handler);
    fn.call(OAuthManagerBridge, ...args);
  });
};

export default class Manager {
  constructor(opts={}) {
    this._options = opts;

    if (opts) {
      this.configureProviders(opts);
    }
  }

  configureProvider(name, props) {
    return OAuthManagerBridge.configureProvider(name, props)
      .then(() => this.setCredentialsForProvider(name));
  }

  configureProviders(providerConfigs) {
    const promises = Object
            .keys(providerConfigs)
            .map(name =>
              this.configureProvider(name, providerConfigs[name]));
    return Promise.all(promises);
  }

  setCredentialsForProvider(providerName, credentials) {
    const handleHydration = (creds) => promisify(OAuthManagerBridge.setCredentialsForProvider)(providerName, creds);

    if (!credentials) {
      return new Promise((resolve, reject) => {
        const storageKey = this.makeStorageKey(providerName);
        AsyncStorage.getItem(storageKey, (err, res) => {
          if (err) {
            return reject('No credentials passed or found in storage');
          } else {
            try {
              const json = JSON.parse(res);
              const next = handleHydration(json);
              return resolve(next);
            } catch (err) {
              return reject(err);
            }
          }
        });
      });
    } else {
      return handleHydration(credentials);
    }
  }

  authorizeWithCallbackURL(provider, url, scope, state, params) {
    return OAuthManagerBridge
            .authorizeWithCallbackURL(provider, url, scope, state, params)
            .then((res) => {
              return new Promise((resolve, reject) => {
                const json = JSON.stringify(res);
                AsyncStorage.setItem(this.makeStorageKey(provider), json, (err) => {
                  console.log('setItem for storageKey -->', this.makeStorageKey(provider), JSON.stringify(res));
                  if (err) {
                    return reject(err);
                  } else {
                    return resolve(res);
                  }
                })
              });
            })
  }

  makeRequest(provider, method, url, parameters={}, headers={}) {
    return promisify(OAuthManagerBridge.makeSignedRequest)(
      provider, method, url, parameters, headers);
  }

  deauthorize(providerName) {
    return new Promise((resolve, reject) => {
      AsyncStorage.removeItem(this.makeStorageKey(providerName), (err) => {
        return err ? reject(err) : resolve();
      })
    })
  }

  static providers() {
    return promisify(OAuthManagerBridge.providers)();
  }

  makeStorageKey(path, prefix='credentials') {
    return `${STORAGE_KEY}/${prefix}/${path}`.toLowerCase();
  }
}
