package io.fullstack.oauth;

import android.util.Log;
import android.content.Context;
import android.net.Uri;
import android.os.Handler;
import android.content.SharedPreferences;

import java.net.URL;
import java.net.MalformedURLException;

import android.support.annotation.Nullable;
import android.app.FragmentManager;
import android.support.v4.app.FragmentActivity;
import android.app.Activity;
import android.text.TextUtils;

import java.io.IOException;
import java.util.Map;
import java.util.Set;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReadableType;
import com.facebook.react.bridge.ReadableMapKeySetIterator;
import com.facebook.react.bridge.ReactContext;

import com.github.scribejava.core.builder.api.BaseApi;

// import com.wuman.android.auth.AuthorizationDialogController;
// import com.wuman.android.auth.AuthorizationFlow;
// import com.wuman.android.auth.DialogFragmentController;
// import com.wuman.android.auth.OAuthManager;
// import com.wuman.android.auth.OAuthManager.OAuthCallback;
// import com.wuman.android.auth.OAuthManager.OAuthFuture;
// import com.wuman.android.auth.oauth2.store.SharedPreferencesCredentialStore;
// import com.wuman.android.auth.oauth2.store.FilePersistedCredential;

// import com.google.api.client.auth.oauth2.BearerToken;
// import com.google.api.client.auth.oauth2.ClientParametersAuthentication;
// import com.google.api.client.auth.oauth2.Credential;
// import com.google.api.client.auth.oauth2.StoredCredential;

// import com.google.api.client.extensions.android.http.AndroidHttp;
// import com.google.api.client.http.GenericUrl;
// import com.google.api.client.http.HttpTransport;
// import com.google.api.client.json.JsonFactory;
// import com.google.api.client.json.jackson2.JacksonFactory;
import com.github.scribejava.core.builder.ServiceBuilder;
import com.github.scribejava.core.model.OAuth1AccessToken;
import com.github.scribejava.core.model.OAuth1RequestToken;
import com.github.scribejava.core.model.OAuthRequest;
import com.github.scribejava.core.model.Response;
import com.github.scribejava.core.model.Verb;
import com.github.scribejava.core.oauth.OAuth10aService;

class ProviderNotConfiguredException extends Exception {
  public ProviderNotConfiguredException(String message) {
    super(message);
  }
}

@SuppressWarnings("WeakerAccess")
class OAuthManagerModule extends ReactContextBaseJavaModule {
  private static final String TAG = "OAuthManager";

  private Context context;
  private ReactContext mReactContext;

  private HashMap _configuration = new HashMap<String, HashMap<String,String>>();
  private ArrayList _callbackUrls  = new ArrayList<String>();
  private OAuthManagerStore _credentialsStore;

  public OAuthManagerModule(ReactApplicationContext reactContext) {
    super(reactContext);
    mReactContext = reactContext;

    _credentialsStore = OAuthManagerStore.getOAuthManagerStore(mReactContext, TAG, Context.MODE_PRIVATE);
    Log.d(TAG, "New instance");
  }

  @Override
  public String getName() {
    return TAG;
  }

  @ReactMethod
  public void configureProvider(
    final String providerName, 
    final ReadableMap params, 
    @Nullable final Callback onComplete
  ) {
    Log.i(TAG, "configureProvider for " + providerName);

    // Save callback url for later
    String callbackUrlStr = params.getString("callback_url");
    // TODO: Should we validate the URL or not?
    // Not sure...
    // URL u;
    // try {
      // u = new URL(callbackUrlStr);
    // } catch (MalformedURLException ex) {
      // u = new URL(callbackUrlStr, "", "");
      // return exceptionCallback(ex, onComplete);
    // }
      // String protocol = u.getProtocol();
      // String host = u.getAuthority();
      // String path = u.getPath();
      // String callbackUrl = protocol + "://" + host + path;
      _callbackUrls.add(callbackUrlStr);
    

    // Keep configuration map
    HashMap<String, String> cfg = new HashMap<String,String>();

    ReadableMapKeySetIterator iterator = params.keySetIterator();
    while (iterator.hasNextKey()) {
      String key = iterator.nextKey();
      ReadableType readableType = params.getType(key);
      switch(readableType) {
        case String:
          String val = params.getString(key);
          // String escapedVal = Uri.encode(val);
          cfg.put(key, val);
          break;
        default:
          throw new IllegalArgumentException("Could not read object with key: " + key);
      }
    }

    _configuration.put(providerName, cfg);

    onComplete.invoke(null, true);
  }

  @ReactMethod
  public void authorize(
    final String providerName, 
    @Nullable final ReadableMap params, 
    final Callback callback) 
  {
    try {
      final OAuthManagerModule self = this;
      HashMap<String,String> cfg = this.getConfiguration(providerName);
      final String authVersion = (String) cfg.get("auth_version");
      Activity activity = mReactContext.getCurrentActivity();
      FragmentManager fragmentManager = activity.getFragmentManager();
      String callbackUrl = "http://localhost/" + providerName;
      
      if (authVersion.equals("1.0")) {
        final OAuth10aService service = 
          OAuthManagerProviders.getApiFor10aProvider(providerName, cfg, callbackUrl);

        OAuthManagerFragmentController ctrl =
          new OAuthManagerFragmentController(fragmentManager, providerName, service, callbackUrl);

        ctrl.requestAuth(new OAuthManagerOnAccessTokenListener() {
          public void onRequestTokenError(final Exception ex) {}
          public void onOauth1AccessToken(final OAuth1AccessToken accessToken) {
            _credentialsStore.store(providerName, accessToken);
            _credentialsStore.commit();

            WritableMap resp = self.accessTokenResponse(providerName, accessToken, authVersion);
            callback.invoke(null, resp);
          }
        });
        
      } else {
        Log.d(TAG, "Auth version unknown: " + (String) cfg.get("auth_version"));
      }
    } catch (Exception ex) {
      Log.d(TAG, "Exception in callback " + ex.getMessage());
      exceptionCallback(ex, callback);
    }
  }

  @ReactMethod
  public void makeRequest(
    final String providerName, 
    final String urlString,
    final ReadableMap params, 
    final Callback onComplete) {

      Log.i(TAG, "makeRequest called for " + providerName + " to " + urlString);
      // try {
      //   Credential creds = this.loadCredentialForProvider(providerName, params);
      //   HashMap<String,String> cfg = this.getConfiguration(providerName);
      //   final String authVersion = (String) cfg.get("auth_version");

      //   URL url;
      //   try {
      //     if (urlString.contains("http")) {
      //       url = new URL(urlString);
      //     }  else {
      //       String apiHost = (String) cfg.get("api_url");
      //       url  = new URL(apiHost + urlString);
      //     }
      //   } catch (MalformedURLException ex) {
      //     Log.e(TAG, "Bad url. Check request and try again: " + ex.getMessage());
      //     exceptionCallback(ex, onComplete);
      //     return;
      //   }

        
 
      // } catch (Exception ex) {
      //   Log.e(TAG, "Exception when making request: " + ex.getMessage());
      //   exceptionCallback(ex, onComplete);
      // }
  }

  @ReactMethod
  public void getSavedAccounts(final ReadableMap options, final Callback onComplete) {
    // Log.d(TAG, "getSavedAccounts");
  }

  @ReactMethod
  public void getSavedAccount(
    final String providerName, 
    final ReadableMap options, 
    final Callback onComplete)
  {
    try {
      HashMap<String,String> cfg = this.getConfiguration(providerName);
      final String authVersion = (String) cfg.get("auth_version");

      Log.i(TAG, "getSavedAccount for " + providerName);

      if (authVersion.equals("1.0")) {
        OAuth1AccessToken token = _credentialsStore.get(providerName, OAuth1AccessToken.class);
        Log.d(TAG, "Found token: " + token);

        WritableMap resp = this.accessTokenResponse(providerName, token, authVersion);
        onComplete.invoke(null, resp);
      } else {

      }
    } catch (ProviderNotConfiguredException ex) {
      Log.e(TAG, "Provider not yet configured: " + providerName);
      exceptionCallback(ex, onComplete);
    } catch (Exception ex) {
      Log.e(TAG, "An exception occurred getSavedAccount: " + ex.getMessage());
      ex.printStackTrace();
      exceptionCallback(ex, onComplete);
    }
    
    
    // try {
    //   Credential creds = this.loadCredentialForProvider(providerName, options);
    //   HashMap<String,String> cfg = this.getConfiguration(providerName);
    //   final String authVersion = (String) cfg.get("auth_version");

    //   WritableMap resp = Arguments.createMap();
    //   WritableMap response = Arguments.createMap();

    //   resp.putString("provider", providerName);

    //   if (creds == null) {
    //     resp.putString("status", "error");
    //     response.putString("msg", "No saved account");

    //     resp.putMap("response", response);
    //     onComplete.invoke(resp);
    //     return;
    //   }

    //   Log.d(TAG, "accessTokenResponse = " + creds);
    //   resp.putString("status", "ok");
      
    //   response.putBoolean("authorized", true); // I think?
    //   response.putString("uuid", "");
      
    //   if (authVersion.equals("1.0")) {
    //     response.putString("oauth_token", creds.getAccessToken());
    //   } else if (authVersion.equals("2.0")) {
    //     // TODO
    //   }
    //   resp.putMap("response", response);
    //   onComplete.invoke(null, resp);
      
    //   } catch (IOException ex) {
    //     Log.e(TAG, "Exception occurred when loading credentials: " + ex.getMessage());
    //     exceptionCallback(ex, onComplete);
    //   } catch (Exception ex) {
    //     Log.e(TAG, "Exception occurred when loading credential: " + ex.getMessage());
    //     exceptionCallback(ex, onComplete);
    //   }
  }

  @ReactMethod
  public void deauthorize(final String providerName, final Callback onComplete) {
    try {
      Log.i(TAG, "deauthorizing " + providerName);
      HashMap<String,String> cfg = this.getConfiguration(providerName);
      final String authVersion = (String) cfg.get("auth_version");

      _credentialsStore.delete(providerName);

      WritableMap resp = Arguments.createMap();
      resp.putString("status", "ok");

      onComplete.invoke(null, resp);
    } catch (Exception ex) {
      exceptionCallback(ex, onComplete);
    }
    // try {
    //   OAuthManager manager = this.getManager(providerName, null, true);
    //   OAuthCallback<Boolean> cb = new OAuthCallback<Boolean>() {
    //     @Override
    //     public void run(OAuthFuture<Boolean> future) {
    //       try {
    //         Boolean res = future.getResult();
    //         WritableMap resp = Arguments.createMap();
            
    //         if (res) {
    //           resp.putString("status", "ok");
    //           onComplete.invoke(null, resp);
    //         } else {
    //           resp.putString("status", "error");
    //           resp.putString("msg", "No account found");
    //           onComplete.invoke(resp);
    //         }
    //       } catch (IOException ex) {
    //         Log.d(TAG, "Exception in callback " + ex.getMessage());
    //         exceptionCallback(ex, onComplete);
    //       }
    //     }
    //   };

    //   manager.deleteCredential(providerName, cb, new Handler());
    // } catch (Exception ex) {
    //   Log.e(TAG, "Exception with deauthorize " + ex.getMessage());
    //   exceptionCallback(ex, onComplete);
    // }
  }

  // private Credential loadCredentialForProvider(
  //   final String providerName,
  //   final ReadableMap options
  // ) throws Exception {
  //   HashMap<String,String> cfg = this.getConfiguration(providerName);
  //   final String authVersion = (String) cfg.get("auth_version");

  //   AuthorizationFlow flow = this.oauthManagerFlow(providerName, options);

  //   Credential creds;
  //   if (authVersion.equals("1.0")) {
  //     creds = flow.load10aCredential(providerName);
  //   } else if (authVersion.equals("2.0")) {
  //     creds = flow.loadCredential(providerName);
  //   } else {
  //     return null;
  //   }

  //   return creds;
  // }

  private HashMap<String,String> getConfiguration(
    final String providerName
  ) throws Exception {
    if (!_configuration.containsKey(providerName)) {
      throw new ProviderNotConfiguredException("Provider not configured: " + providerName);
    }

    HashMap<String,String> cfg = (HashMap) _configuration.get(providerName);
    return cfg;
  }

  private WritableMap accessTokenResponse(
    final String providerName,
    final OAuth1AccessToken accessToken,
    final String oauthVersion
  ) {
    WritableMap resp = Arguments.createMap();
    WritableMap response = Arguments.createMap();

    resp.putString("status", "ok");
    resp.putString("provider", providerName);
    response.putString("uuid", accessToken.getParameter("user_id"));
    
    WritableMap credentials = Arguments.createMap();
    credentials.putString("oauth_token", accessToken.getToken());
    credentials.putString("oauth_secret", accessToken.getTokenSecret());
    response.putMap("credentials", credentials);

    resp.putMap("response", response);

    return resp;
  }

  // private OAuthManager getManager(
  //   final String providerName,
  //   @Nullable final ReadableMap params,
  //   final boolean fullScreen
  // ) throws Exception {
  //   Log.i(TAG, "getManager");

  //   AuthorizationFlow flow = this.oauthManagerFlow(providerName, params);
  //   AuthorizationDialogController ctrl = 
  //     this.getController(providerName, fullScreen);

  //   Log.d(TAG, "Creating manager " + flow + " " + ctrl);
  //   OAuthManager manager = new OAuthManager(flow, ctrl);

  //   return manager;
  // }

  // private AuthorizationFlow oauthManagerFlow(
  //   final String providerName,
  //   final ReadableMap params
  // ) throws Exception {
  //   Log.i(TAG, "oauthManagerFlow");

  //   HashMap<String,String> cfg = this.getConfiguration(providerName);
  //   final String authVersion = (String) cfg.get("auth_version");

  //   ClientParametersAuthentication client;

  //   if (authVersion.equals("1.0")) {
  //     client = new ClientParametersAuthentication(
  //       (String) cfg.get("consumer_key"),
  //       (String) cfg.get("consumer_secret")
  //     );
    
  //     AuthorizationFlow.Builder flowBuilder = new AuthorizationFlow.Builder(
  //       BearerToken.authorizationHeaderAccessMethod(),
  //       HTTP_TRANSPORT,
  //       JSON_FACTORY,
  //       new GenericUrl((String) cfg.get("access_token_url")),
  //       client,
  //       client.getClientId(),
  //       (String) cfg.get("authorize_url")
  //     )
  //     .setCredentialStore(_credentialsStore);

  //     if (((String) cfg.get("auth_version")).equals("1.0")) {
  //       String tmpRequestUrl = (String) cfg.get("request_token_url");
  //       flowBuilder.setTemporaryTokenRequestUrl(tmpRequestUrl);
  //     }

  //     if (params != null) {
  //       String scopes = null;
  //       if (params.hasKey("scopes")) {
  //         scopes = params.getString("scopes");
  //       } else if (cfg.containsKey("scopes")) {
  //         scopes = (String) cfg.get("scopes");
  //       }

  //       if (scopes != null) {
  //         flowBuilder.setScopes(scopes);
  //       }
  //     }
      
  //     return flowBuilder.build();
  //   } else {
  //     return null;
  //   }
  // }

  // private AuthorizationDialogController getController(
  //   final String providerName,
  //   final boolean fullScreen
  // ) throws Exception {
  //   Activity activity = mReactContext.getCurrentActivity();
  //   FragmentManager fragmentManager = activity.getFragmentManager();
  //   // OAuthManagerWebView act = new OAuthManagerWebView(mReactContext);
  //   // FragmentManager fm = act.getSupportFragmentManager();

  //   final HashMap<String,String> cfg = this.getConfiguration(providerName);
  //   final String authVersion = (String) cfg.get("auth_version");

    // AuthorizationDialogController controller = 
    //   new OAuthManagerFragmentController(fragmentManager, fullScreen) {
    //     // @Override
    //     public String getRedirectUri() throws IOException {
    //       // String redirectUrl = (String) cfg.get("callback_url");
    //       // if (redirectUrl == null) {
    //         String appName = (String) cfg.get("app_name");
    //         // redirectUrl = appName + "://oauth-response/" + providerName;
    //         String redirectUrl = "http://localhost/oauth-response/" + providerName;
    //       // }
    //       return redirectUrl;
    //     }

    //     // @Override
    //     public boolean isJavascriptEnabledForWebView() {
    //       return true;
    //     }

    //     // @Override
    //     public boolean disableWebViewCache() {
    //       return false;
    //     }

    //     // @Override
    //     public boolean removePreviousCookie() {
    //       return false;
    //     }
    //   };

  //   return controller;
  // }

  private void exceptionCallback(Exception ex, final Callback onFail) {
    WritableMap error = Arguments.createMap();
    error.putInt("errorCode", ex.hashCode());
    error.putString("errorMessage", ex.getMessage());
    error.putString("allErrorMessage", ex.toString());

    onFail.invoke(error);
  }
}
