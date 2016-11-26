package io.fullstack.oauth;

import java.io.IOException; 
import com.github.scribejava.core.model.OAuth1AccessToken;
import com.github.scribejava.core.model.OAuth2AccessToken;

public interface OAuthManagerOnAccessTokenListener {
  void onOAuth1AccessToken(final OAuth1AccessToken accessToken); 
  void onOAuth2AccessToken(final OAuth2AccessToken accessToken);
  void onRequestTokenError(final Exception ex);
}