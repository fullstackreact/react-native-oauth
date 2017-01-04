package io.fullstack.oauth;

import android.util.Log;
import java.util.HashMap;
import java.util.Random;

import com.github.scribejava.core.builder.api.BaseApi;
import com.github.scribejava.core.oauth.OAuthService;
import com.github.scribejava.core.oauth.OAuth10aService;
import com.github.scribejava.core.builder.ServiceBuilder;
import com.github.scribejava.core.model.OAuth1AccessToken;
import com.github.scribejava.core.model.OAuth1RequestToken;
import com.github.scribejava.core.model.OAuthRequest;

import com.github.scribejava.core.model.OAuth2AccessToken;
import com.github.scribejava.core.oauth.OAuth20Service;

import com.github.scribejava.apis.TwitterApi;
import com.github.scribejava.apis.FacebookApi;
import com.github.scribejava.apis.GoogleApi20;
import com.github.scribejava.apis.GitHubApi;

public class OAuthManagerProviders {
  private static final String TAG = "OAuthManagerProviders";

  static public OAuth10aService getApiFor10aProvider(
    final String providerName,
    final HashMap params,
    final String callbackUrl
  ) {
    if (providerName.equalsIgnoreCase("twitter")) {
      return OAuthManagerProviders.twitterService(params, callbackUrl);
    } else {
      return null;
    }
  }

  static public OAuth20Service getApiFor20Provider(
    final String providerName,
    final HashMap params,
    final String callbackUrl
  ) {
    if (providerName.equalsIgnoreCase("facebook")) {
      return OAuthManagerProviders.facebookService(params, callbackUrl);
    } else if (providerName.equalsIgnoreCase("google")) {
      return OAuthManagerProviders.googleService(params, callbackUrl);
    } else if (providerName.equalsIgnoreCase("github")) {
      return OAuthManagerProviders.githubService(params, callbackUrl);
    } else {
      return null;
    }
  }

  private static OAuth10aService twitterService(final HashMap cfg, final String callbackUrl) {
    String consumerKey = (String) cfg.get("consumer_key");
    String consumerSecret = (String) cfg.get("consumer_secret");
    
    ServiceBuilder builder = new ServiceBuilder()
          .apiKey(consumerKey)
          .apiSecret(consumerSecret)
          .debug();

    String scopes = (String) cfg.get("scopes");
    if (scopes != null) {
      builder.scope(scopes);
    }

    if (callbackUrl != null) {
      builder.callback(callbackUrl);
    }
    
    return builder.build(TwitterApi.instance());
  }

  private static OAuth20Service facebookService(final HashMap cfg, final String callbackUrl) {
    String clientKey = (String) cfg.get("client_id");
    String clientSecret = (String) cfg.get("client_secret");
    String state;
    if (cfg.containsKey("state")) {
      state = (String) cfg.get("state");
    } else {
      state = TAG + new Random().nextInt(999_999);
    }

    ServiceBuilder builder = new ServiceBuilder()
      .apiKey(clientKey)
      .apiSecret(clientSecret)
      .state(state)
      .debug();

    String scopes = (String) cfg.get("scopes");
    if (scopes != null) {
      builder.scope(scopes);
    }
    
    if (callbackUrl != null) {
      builder.callback(callbackUrl);
    }

    return builder.build(FacebookApi.instance());
  }

  private static OAuth20Service googleService(final HashMap cfg, final String callbackUrl) {
    String clientKey = (String) cfg.get("client_id");
    String clientSecret = (String) cfg.get("client_secret");
    String state;
    if (cfg.containsKey("state")) {
      state = (String) cfg.get("state");
    } else {
      state = TAG + new Random().nextInt(999_999);
    }

    String scope = "profile";
    if (cfg.containsKey("scopes")) {
      scope = (String) cfg.get("scopes");
    }

    ServiceBuilder builder = new ServiceBuilder()
      .apiKey(clientKey)
      .apiSecret(clientSecret)
      .state(state)
      .scope(scope)
      .debug();
    
    if (callbackUrl != null) {
      builder.callback(callbackUrl);
    }

    return builder.build(GoogleApi20.instance());
  }

  private static OAuth20Service githubService(final HashMap cfg, final String callbackUrl) {
    String clientKey = (String) cfg.get("client_id");
    String clientSecret = (String) cfg.get("client_secret");
    String state;
    if (cfg.containsKey("state")) {
      state = (String) cfg.get("state");
    } else {
      state = TAG + new Random().nextInt(999_999);
    }
    String scope = "profile";
    if (cfg.containsKey("scopes")) {
      scope = (String) cfg.get("scopes");
    }

    ServiceBuilder builder = new ServiceBuilder()
      .apiKey(clientKey)
      .apiSecret(clientSecret)
      .state(state)
      .scope(scope)
      .debug();
    
    if (callbackUrl != null) {
      builder.callback(callbackUrl);
    }

    return builder.build(GitHubApi.instance());
  }
}