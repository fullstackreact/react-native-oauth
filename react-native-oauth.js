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
import defaultProviders from './lib/authProviders';

let authProviders = defaultProviders;

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

  addProvider(provider) {
     Object.assign(authProviders, provider);
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

  savedAccounts(opts={}) {
    // const options = Object.assign({}, this._options, opts, {
      // app_name: this.appName
    // })
    // return promisify('getSavedAccounts')(options);
    const promises = this.providers()
                          .map(name => {
                            return this.savedAccount(name)
                              .catch(err => ({provider: name, status: "error"}));
                          });
    return Promise.all(promises)
      .then((accountResp) => {
        const accounts = accountResp.filter(acc => acc.status == "ok");
        return { accounts }
      });
  }

  savedAccount(provider) {
    const options = Object.assign({}, this._options, {
      app_name: this.appName
    })
    return promisify('getSavedAccount')(provider, options);
  }

  makeRequest(provider, url, opts={}) {
    const options = Object.assign({}, this._options, opts, {
      app_name: this.appName
    });

    console.log('making request', provider, url, opts);

    return promisify('makeRequest')(provider, url, options)
      .then(response => {
        // Little bit of a hack to support Android until we have a better
        // way of decoding the JSON response on the Android side
        if (response && response.data && typeof response.data === "string") {
          response.data = JSON.parse(response.data);
        }
        return response;
      });
  }

  deauthorize(provider) {
    return promisify('deauthorize')(provider);
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

  // Private
  /**
   * Configure a single provider
   *
   *
   * @param {string} name of the provider
   * @param {object} additional configuration
   *
   **/
  configureProvider(name, props) {
    invariant(OAuthManager.isSupported(name), `The provider ${name} is not supported yet`);

    const providerCfg = Object.assign({}, authProviders[name]);
    let { validate = identity, transform = identity, callback_url } = providerCfg;
    delete providerCfg.transform;
    delete providerCfg.validate;

    let config = Object.assign({}, {
      app_name: this.appName,
      callback_url
    }, providerCfg, props);

    if (config.defaultParams) {
      delete config.defaultParams;
    }

    config = Object.keys(config)
      .reduce((sum, key) => ({
        ...sum,
        [key]: typeof config[key] === 'function' ? config[key](config) : config[key]
      }), {});

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
