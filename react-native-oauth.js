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
    return promisify('authorizeWithAppName')(provider, this.appName, opts);
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

    const providerCfg = authProviders[name];
    let { isValid } = providerCfg;
    if (!isValid) {
      isValid = () => true;
    }
    const { consumer_key, consumer_secret } = props;

    const config = Object.assign({}, 
                    providerCfg.defaults,
                    {consumer_key, consumer_secret});

    const valid = isValid(config);
    console.log('valid ->', valid);
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
