import {NativeModules, NativeAppEventEmitter} from 'react-native';
const OAuthManagerBridge = NativeModules.OAuthManager;

export const promisify = (fn, NativeModule) => (...args) => {
  const Module = NativeModule ? NativeModule : OAuthManagerBridge;
  return new Promise((resolve, reject) => {
    const handler = (err, resp) => {
      err ? reject(err) : resolve(resp);
    }
    args.push(handler);
    (typeof fn === 'function' ? fn : Module[fn])
      .call(Module, ...args);
  });
};

export default promisify