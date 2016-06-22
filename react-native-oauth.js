/**
 * @providesModule OAuthManager
 * @flow
 */
import {NativeModules, NativeAppEventEmitter} from 'react-native';
const OAuthManagerBridge = NativeModules.OAuthManager;

let configured = false;

const promisify = fn => (...args) => {
  return new Promise((resolve, reject) => {
    const handler = (err, resp) => err ? reject(err) : resolve(resp);
    args.push(handler);
    fn.call(OAuthManagerBridge, ...args);
  });
};

export default class Manager {
  constructor() {}

  configureProvider(name, props) {
    return OAuthManagerBridge.configureProvider(name, props);
  }

  authorizeWithCallbackURL(provider, url) {
    return OAuthManagerBridge.authorizeWithCallbackURL(provider, url);
  }

  static providers() {
    return promisify(OAuthManagerBridge.providers)();
  }
}
