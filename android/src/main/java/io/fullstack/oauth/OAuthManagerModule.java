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
import com.github.scribejava.core.model.Verb;

import com.github.scribejava.core.builder.ServiceBuilder;
import com.github.scribejava.core.model.OAuth1AccessToken;
import com.github.scribejava.core.model.OAuth1RequestToken;
import com.github.scribejava.core.model.OAuthRequest;
import com.github.scribejava.core.model.Response;
import com.github.scribejava.core.model.Verb;
import com.github.scribejava.core.oauth.OAuth10aService;

import com.github.scribejava.core.model.OAuth2AccessToken;
import com.github.scribejava.core.oauth.OAuth20Service;

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

  private HashMap _configuration = new HashMap<String, HashMap<String,Object>>();
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
    _callbackUrls.add(callbackUrlStr);
    

    // Keep configuration map
    HashMap<String, Object> cfg = new HashMap<String,Object>();

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
      HashMap<String,Object> cfg = this.getConfiguration(providerName);
      final String authVersion = (String) cfg.get("auth_version");
      Activity activity = mReactContext.getCurrentActivity();
      FragmentManager fragmentManager = activity.getFragmentManager();
      String callbackUrl = "http://localhost/" + providerName;
      
      OAuthManagerOnAccessTokenListener listener = new OAuthManagerOnAccessTokenListener() {
        public void onRequestTokenError(final Exception ex) {}
        public void onOAuth1AccessToken(final OAuth1AccessToken accessToken) {
          _credentialsStore.store(providerName, accessToken);
          _credentialsStore.commit();

          WritableMap resp = self.accessTokenResponse(providerName, accessToken, authVersion);
          callback.invoke(null, resp);
        }
        public void onOAuth2AccessToken(final OAuth2AccessToken accessToken) {
          _credentialsStore.store(providerName, accessToken);
          _credentialsStore.commit();

          WritableMap resp = self.accessTokenResponse(providerName, accessToken, authVersion);
          callback.invoke(null, resp);
        }
      };

      if (authVersion.equals("1.0")) {
        final OAuth10aService service = 
          OAuthManagerProviders.getApiFor10aProvider(providerName, cfg, callbackUrl);

        OAuthManagerFragmentController ctrl =
          new OAuthManagerFragmentController(fragmentManager, providerName, service, callbackUrl);

        ctrl.requestAuth(cfg, listener);
      } else if (authVersion.equals("2.0")) {
        final OAuth20Service service =
          OAuthManagerProviders.getApiFor20Provider(providerName, cfg, callbackUrl);
        
        OAuthManagerFragmentController ctrl =
          new OAuthManagerFragmentController(fragmentManager, providerName, service, callbackUrl);

        ctrl.requestAuth(cfg, listener);
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
      try {
        HashMap<String,Object> cfg = this.getConfiguration(providerName);
        final String authVersion = (String) cfg.get("auth_version");

        URL url;
        try {
          if (urlString.contains("http")) {
            url = new URL(urlString);
          }  else {
            String apiHost = (String) cfg.get("api_url");
            url  = new URL(apiHost + urlString);
          }
        } catch (MalformedURLException ex) {
          Log.e(TAG, "Bad url. Check request and try again: " + ex.getMessage());
          exceptionCallback(ex, onComplete);
          return;
        }

        String httpMethod;
        if (params.hasKey("method")) { 
          httpMethod = params.getString("method");
        } else {
          httpMethod = "GET";
        }

        Verb httpVerb;
        if (httpMethod.equalsIgnoreCase("GET")) {
          httpVerb = Verb.GET;
        } else if (httpMethod.equalsIgnoreCase("POST")) {
          httpVerb = Verb.POST;
        } else if (httpMethod.equalsIgnoreCase("PUT")) {
          httpVerb = Verb.PUT;
        } else if (httpMethod.equalsIgnoreCase("DELETE")) {
          httpVerb = Verb.DELETE;
        } else if (httpMethod.equalsIgnoreCase("OPTIONS")) {
          httpVerb = Verb.OPTIONS;
        } else if (httpMethod.equalsIgnoreCase("HEAD")) {
          httpVerb = Verb.HEAD;
        } else if (httpMethod.equalsIgnoreCase("PATCH")) {
          httpVerb = Verb.PATCH;
        } else if (httpMethod.equalsIgnoreCase("TRACE")) {
          httpVerb = Verb.TRACE;
        } else {
          httpVerb = Verb.GET;
        }
        
        OAuthRequest request;
        if (authVersion.equals("1.0")) {
          final OAuth10aService service = 
            OAuthManagerProviders.getApiFor10aProvider(providerName, cfg, null);
          OAuth1AccessToken token = _credentialsStore.get(providerName, OAuth1AccessToken.class);
          
          request = new OAuthRequest(httpVerb, url.toString(), service);
          service.signRequest(token, request);
        } else if (authVersion.equals("2.0")) {
          final OAuth20Service service =
            OAuthManagerProviders.getApiFor20Provider(providerName, cfg, null);
          OAuth2AccessToken token = _credentialsStore.get(providerName, OAuth2AccessToken.class);

          request = new OAuthRequest(httpVerb, url.toString(), service);
          service.signRequest(token, request);
        } else {
          // Some kind of error here
          Log.e(TAG, "An error occurred");
          WritableMap err = Arguments.createMap();
          err.putString("status", "error");
          err.putString("msg", "A weird error occurred");
          onComplete.invoke(err);
          return;
        }
        
        final Response response = request.send();
        final String rawBody = response.getBody();

        Log.d(TAG, "rawBody: " + rawBody);
        // final Object response = new Gson().fromJson(rawBody, Object.class);

        WritableMap resp = Arguments.createMap();
        resp.putInt("status", response.getCode());
        resp.putString("data", rawBody);
        onComplete.invoke(null, resp);
 
      } catch (IOException ex) {
        Log.e(TAG, "IOException when making request: " + ex.getMessage());
        ex.printStackTrace();
        exceptionCallback(ex, onComplete);
      } catch (Exception ex) {
        Log.e(TAG, "Exception when making request: " + ex.getMessage());
        exceptionCallback(ex, onComplete);
      }
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
      HashMap<String,Object> cfg = this.getConfiguration(providerName);
      final String authVersion = (String) cfg.get("auth_version");

      Log.i(TAG, "getSavedAccount for " + providerName);

      if (authVersion.equals("1.0")) {
        OAuth1AccessToken token = _credentialsStore.get(providerName, OAuth1AccessToken.class);
        Log.d(TAG, "Found token: " + token);
        if (token == null || token.equals("")) {
          throw new Exception("No token found");
        }

        WritableMap resp = this.accessTokenResponse(providerName, token, authVersion);
        onComplete.invoke(null, resp);
      } else if (authVersion.equals("2.0")) {
        OAuth2AccessToken token = _credentialsStore.get(providerName, OAuth2AccessToken.class);
        
        if (token == null || token.equals("")) {
          throw new Exception("No token found");
        }
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
    
  }

  @ReactMethod
  public void deauthorize(final String providerName, final Callback onComplete) {
    try {
      Log.i(TAG, "deauthorizing " + providerName);
      HashMap<String,Object> cfg = this.getConfiguration(providerName);
      final String authVersion = (String) cfg.get("auth_version");

      _credentialsStore.delete(providerName);

      WritableMap resp = Arguments.createMap();
      resp.putString("status", "ok");

      onComplete.invoke(null, resp);
    } catch (Exception ex) {
      exceptionCallback(ex, onComplete);
    }
  }


  private HashMap<String,Object> getConfiguration(
    final String providerName
  ) throws Exception {
    if (!_configuration.containsKey(providerName)) {
      throw new ProviderNotConfiguredException("Provider not configured: " + providerName);
    }

    HashMap<String,Object> cfg = (HashMap) _configuration.get(providerName);
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

  private WritableMap accessTokenResponse(
    final String providerName,
    final OAuth2AccessToken accessToken,
    final String oauthVersion
  ) {
    WritableMap resp = Arguments.createMap();
    WritableMap response = Arguments.createMap();

    resp.putString("status", "ok");
    resp.putString("provider", providerName);
    try {
      response.putString("uuid", accessToken.getParameter("user_id"));
    } catch (Exception ex) {
      Log.e(TAG, "Exception while getting the access token");
      ex.printStackTrace();
    }
    
    WritableMap credentials = Arguments.createMap();
    credentials.putString("oauth_token", accessToken.getAccessToken());
    credentials.putString("oauth_secret", "");
    credentials.putString("scope", accessToken.getScope());
    response.putMap("credentials", credentials);

    resp.putMap("response", response);

    return resp;
  }
  

  private void exceptionCallback(Exception ex, final Callback onFail) {
    WritableMap error = Arguments.createMap();
    error.putInt("errorCode", ex.hashCode());
    error.putString("errorMessage", ex.getMessage());
    error.putString("allErrorMessage", ex.toString());

    onFail.invoke(error);
  }
}
