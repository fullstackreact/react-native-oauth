/**
 * @providesModule OAuthManager
 * @flow
 */
import {
  NativeModules,
  AsyncStorage
} from 'react-native';
import invariant from 'invariant';

const OAuthManagerBridge = NativeModules.OAuthManager;

let configured = false;
const STORAGE_KEY = 'ReactNativeOAuth';
import promisify from './lib/promisify'
import authProviders from './lib/authProviders';

const identity = (props) => props;
/**
 * Manager is the OAuth layer
 **/
export default class OAuthManager {
  constructor(appName, opts={}) {
    invariant(appName && appName != '', `You must provide an appName to the OAuthManager`);

    this.appName = appName;
    this._options = opts;
  }

  configure(providerConfigs) {
    return this.configureProviders(providerConfigs)
  }

  authorize(provider, opts={}) {
    const options = Object.assign({}, this._options, opts, {
      app_name: this.appName
    })
    return promisify('authorize')(provider, options);
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

  providers() {
    return OAuthManager.providers();
  }

  static providers() {
    return Object.keys(authProviders);
  }

  static isSupported(name) {
    return OAuthManager.providers().indexOf(name) >= 0;
  }

  makeStorageKey(path, prefix='credentials') {
    return `${STORAGE_KEY}/${prefix}/${path}`.toLowerCase();
  }

  // Private
  /**
   * Configure a single provider
   **/
  configureProvider(name, props) {
    invariant(OAuthManager.isSupported(name), `The provider ${name} is not supported yet`);

    const providerCfg = Object.assign({}, authProviders[name]);
    let { validate = identity } = providerCfg;
    let { transform = identity } = providerCfg;
    delete providerCfg.transform;
    delete providerCfg.validate;

    const config = transform(Object.assign({}, {
      app_name: this.appName
    }, providerCfg, props));
    validate(config);
    return promisify('configureProvider')(name, config);
  }

  configureProviders(providerConfigs) {
    providerConfigs = providerConfigs || this._options;
    const promises = Object
            .keys(providerConfigs)
            .map(name =>
              this.configureProvider(name, providerConfigs[name]));
    return Promise.all(promises)
      .then(() => this);
  }
}
