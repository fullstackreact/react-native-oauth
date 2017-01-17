package io.fullstack.oauth;

import android.util.Log;
import java.util.HashMap;
import java.util.Random;
import java.util.List;
import android.support.annotation.Nullable;
import java.net.URL;
import java.net.MalformedURLException;
import android.text.TextUtils;
import java.util.Arrays;

import com.github.scribejava.core.model.Verb;
import com.github.scribejava.core.builder.api.BaseApi;
import com.github.scribejava.core.oauth.OAuthService;
import com.github.scribejava.core.oauth.OAuth10aService;
import com.github.scribejava.core.builder.ServiceBuilder;
import com.github.scribejava.core.model.OAuth1AccessToken;
import com.github.scribejava.core.model.OAuth1RequestToken;
import com.github.scribejava.core.model.OAuthRequest;
import com.github.scribejava.core.model.OAuthConfig;

import com.github.scribejava.core.model.OAuth2AccessToken;
import com.github.scribejava.core.oauth.OAuth20Service;

import com.github.scribejava.apis.TwitterApi;
import com.github.scribejava.apis.FacebookApi;
import com.github.scribejava.apis.GoogleApi20;
import com.github.scribejava.apis.GitHubApi;

import com.github.scribejava.apis.SlackApi;

import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableType;
import com.facebook.react.bridge.ReadableMapKeySetIterator;

public class OAuthManagerProviders {
  private static final String TAG = "OAuthManagerProviders";

  static public OAuth10aService getApiFor10aProvider(
    final String providerName,
    final HashMap params,
    @Nullable final ReadableMap opts,
    final String callbackUrl
  ) {
    if (providerName.equalsIgnoreCase("twitter")) {
      return OAuthManagerProviders.twitterService(params, opts, callbackUrl);
    } else {
      return null;
    }
  }

  static public OAuth20Service getApiFor20Provider(
    final String providerName,
    final HashMap params,
    @Nullable final ReadableMap opts,
    final String callbackUrl
  ) {
    if (providerName.equalsIgnoreCase("facebook")) {
      return OAuthManagerProviders.facebookService(params, opts, callbackUrl);
    } else if (providerName.equalsIgnoreCase("google")) {
      return OAuthManagerProviders.googleService(params, opts, callbackUrl);
    } else if (providerName.equalsIgnoreCase("github")) {
      return OAuthManagerProviders.githubService(params, opts, callbackUrl);
    } else if (providerName.equalsIgnoreCase("slack")) {
      return OAuthManagerProviders.slackService(params, opts, callbackUrl);
    } else {
      return null;
    }
  }

  static public OAuthRequest getRequestForProvider(
    final String providerName,
    final Verb httpVerb,
    final OAuth1AccessToken oa1token,
    final URL url,
    final HashMap<String,Object> cfg,
    @Nullable final ReadableMap params
  ) {
    final OAuth10aService service = 
          OAuthManagerProviders.getApiFor10aProvider(providerName, cfg, null, null);
    
    String token = oa1token.getToken();
    OAuthConfig config = service.getConfig();
    OAuthRequest request = new OAuthRequest(httpVerb, url.toString(), config);

    request = OAuthManagerProviders.addParametersToRequest(request, token, params);
    // Nothing special for Twitter
    return request;
  }

  static public OAuthRequest getRequestForProvider(
    final String providerName,
    final Verb httpVerb,
    final OAuth2AccessToken oa2token,
    final URL url,
    final HashMap<String,Object> cfg,
    @Nullable final ReadableMap params
  ) {
    final OAuth20Service service =
        OAuthManagerProviders.getApiFor20Provider(providerName, cfg, null, null);
    
    OAuthConfig config = service.getConfig();
    OAuthRequest request = new OAuthRequest(httpVerb, url.toString(), config);
    String token = oa2token.getAccessToken();

    request = OAuthManagerProviders.addParametersToRequest(request, token, params);

    // 
    Log.d(TAG, "Making request for " + providerName + " to add token " + token);
    // Need a way to standardize this, but for now
    if (providerName.equalsIgnoreCase("slack")) {
      request.addParameter("token", token);
    }

    return request;
  }

  // Helper to add parameters to the request
  static private OAuthRequest addParametersToRequest(
    OAuthRequest request,
    final String access_token,
    @Nullable final ReadableMap params
  ) {
    if (params != null && params.hasKey("params")) {
      ReadableMapKeySetIterator iterator = params.keySetIterator();
      while (iterator.hasNextKey()) {
        String key = iterator.nextKey();
        ReadableType readableType = params.getType(key);
        switch(readableType) {
          case String:
            String val = params.getString(key);
            // String escapedVal = Uri.encode(val);
            if (val.equals("access_token")) {
              val = access_token;
            }
            request.addParameter(key, val);
            break;
          default:
            throw new IllegalArgumentException("Could not read object with key: " + key);
        }
      }
    }
    return request;
  }

  private static OAuth10aService twitterService(
    final HashMap cfg, 
    @Nullable final ReadableMap opts,
    final String callbackUrl) {
    String consumerKey = (String) cfg.get("consumer_key");
    String consumerSecret = (String) cfg.get("consumer_secret");
    
    ServiceBuilder builder = new ServiceBuilder()
          .apiKey(consumerKey)
          .apiSecret(consumerSecret)
          .debug();

    String scopes = (String) cfg.get("scopes");
    if (scopes != null) {
      // String scopeStr = OAuthManagerProviders.getScopeString(scopes, "+");
      // Log.d(TAG, "scopeStr: " + scopeStr);
      // builder.scope(scopeStr);
    }

    if (callbackUrl != null) {
      builder.callback(callbackUrl);
    }
    
    return builder.build(TwitterApi.instance());
  }

  private static OAuth20Service facebookService(
    final HashMap cfg, 
    @Nullable final ReadableMap opts,
    final String callbackUrl) {
    ServiceBuilder builder = OAuthManagerProviders._oauth2ServiceBuilder(cfg, opts, callbackUrl);
    return builder.build(FacebookApi.instance());
  }

  private static OAuth20Service googleService(
    final HashMap cfg, 
    @Nullable final ReadableMap opts,
    final String callbackUrl)
  {
    ServiceBuilder builder = OAuthManagerProviders._oauth2ServiceBuilder(cfg, opts, callbackUrl);
    return builder.build(GoogleApi20.instance());
  }

  private static OAuth20Service githubService(
    final HashMap cfg, 
    @Nullable final ReadableMap opts,
    final String callbackUrl)
  {

    ServiceBuilder builder = OAuthManagerProviders._oauth2ServiceBuilder(cfg, opts, callbackUrl);
    return builder.build(GitHubApi.instance());
  }

  private static OAuth20Service slackService(
    final HashMap cfg, 
    @Nullable final ReadableMap opts,
    final String callbackUrl
    ) {

    Log.d(TAG, "Make the builder: " + SlackApi.class);
    ServiceBuilder builder = OAuthManagerProviders._oauth2ServiceBuilder(cfg, opts, callbackUrl);
    return builder.build(SlackApi.instance());
  }

  private static ServiceBuilder _oauth2ServiceBuilder(
    final HashMap cfg,
    @Nullable final ReadableMap opts,
    final String callbackUrl
  ) {
    String clientKey = (String) cfg.get("client_id");
    String clientSecret = (String) cfg.get("client_secret");
    String state;
    if (cfg.containsKey("state")) {
      state = (String) cfg.get("state");
    } else {
      state = TAG + new Random().nextInt(999_999);
    }

    // Builder
    ServiceBuilder builder = new ServiceBuilder()
      .apiKey(clientKey)
      .apiSecret(clientSecret)
      .state(state)
      .debug();

    String scopes = "";
    if (cfg.containsKey("scopes")) {
      scopes = (String) cfg.get("scopes");
      String scopeStr = OAuthManagerProviders.getScopeString(scopes, ",");
      builder.scope(scopeStr);
    }
    
    if (opts != null && opts.hasKey("scopes")) {
      scopes = (String) opts.getString("scopes");
      String scopeStr = OAuthManagerProviders.getScopeString(scopes, ",");
      builder.scope(scopeStr);
    }
    
    if (callbackUrl != null) {
      builder.callback(callbackUrl);
    }

    return builder;
  }

  /**
   * Convert a list of scopes by space or string into an array
   */
  private static String getScopeString(
    final String scopes,
    final String joinBy
  ) {
    List<String> array = Arrays.asList(scopes.replaceAll("\\s", "").split("[ ,]+"));
    Log.d(TAG, "array: " + array + " (" + array.size() + ") from " + scopes);
    return TextUtils.join(joinBy, array);
  }
}