package io.fullstack.oauth;

import java.io.IOException; 
import com.github.scribejava.core.model.OAuth1AccessToken;

public interface OAuthManagerOnAccessTokenListener {
  void onOauth1AccessToken(final OAuth1AccessToken accessToken); 
  void onRequestTokenError(final Exception ex);
}