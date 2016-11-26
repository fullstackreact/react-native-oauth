package io.fullstack.oauth;

import android.util.Log;
import java.util.HashMap;
import com.github.scribejava.core.builder.api.BaseApi;
import com.github.scribejava.core.oauth.OAuthService;
import com.github.scribejava.core.oauth.OAuth10aService;
import com.github.scribejava.core.builder.ServiceBuilder;
import com.github.scribejava.core.model.OAuth1AccessToken;
import com.github.scribejava.core.model.OAuth1RequestToken;
import com.github.scribejava.core.model.OAuthRequest;

import com.github.scribejava.apis.TwitterApi;

public class OAuthManagerProviders {
  private static final String TAG = "OAuthManagerProviders";

  static public OAuth10aService getApiFor10aProvider(
    final String providerName,
    final HashMap params,
    final String callbackUrl
  ) {
    if (providerName.equals("twitter")) {
      return OAuthManagerProviders.twitterService(params, callbackUrl);
    } else {
      return null;
    }
  }

  static public BaseApi getApiFor20Provider(final String providerName) {
    return null;
  }

  private static OAuth10aService twitterService(final HashMap cfg, final String callbackUrl) {
    String consumerKey = (String) cfg.get("consumer_key");
    String consumerSecret = (String) cfg.get("consumer_secret");
    
    ServiceBuilder builder = new ServiceBuilder()
          .apiKey(consumerKey)
          .apiSecret(consumerSecret)
          .debug();

    if (callbackUrl != null) {
      builder.callback(callbackUrl);
    }
    return builder.build(TwitterApi.instance());
  }
}