/**
 * @providesModule OAuthManager
 * @flow
 */
import {
  NativeModules
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
  constructor() {
    // Rehydrate credentials, if there are any
  }

  configureProvider(name, props) {
    return OAuthManagerBridge.configureProvider(name, props);
  }

  configureProviders(providerConfigs) {
    const promises = Object
            .keys(providerConfigs)
            .map(providerName => this.configureProvider(name, providerConfigs[name]));
    return Promises.all(promises);
  }

  setCredentialsForProvider(providerName, credentials) {
    const handleHydration = (creds) => promisify(OAuthManagerBridge.setCredentialsForProvider)(providerName, creds);

    if (!credentials) {
      return new Promise((resolve, reject) => {
        AsyncStorage.getItem(this.makeStorageKey(providerName, (err, res) => {
          if (err) {
            return reject('No credentials passed or found in storage');
          } else {
            try {
              const json = JSON.parse(res);
              const next = handleHydration(res);
              return resolve(next);
            } catch (e) {
              return reject(e);
            }
          }
        })
      })
    } else {
      handleHydration(credentials);
    }
  }

  authorizeWithCallbackURL(provider, url, scope, state, params) {
    return OAuthManagerBridge
            .authorizeWithCallbackURL(provider, url, scope, state, params)
            .then((res) => {
              return new Promise((resolve, reject) => {
                AsyncStorage.setItem(makeStorageKey(provider), JSON.stringify(res), (err) => {
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

  static providers() {
    return promisify(OAuthManagerBridge.providers)();
  }

  makeStorageKey(path) {
    return `${STORAGE_KEY}/${path}`
  }
}
