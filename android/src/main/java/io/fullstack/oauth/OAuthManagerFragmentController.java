package io.fullstack.oauth;

import android.app.Fragment;
import android.app.FragmentTransaction;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.facebook.react.bridge.ReactContext;
import com.github.scribejava.core.exceptions.OAuthConnectionException;
import com.github.scribejava.core.model.OAuth1AccessToken;
import com.github.scribejava.core.model.OAuth1RequestToken;
import com.github.scribejava.core.model.OAuth2AccessToken;
import com.github.scribejava.core.oauth.OAuth10aService;
import com.github.scribejava.core.oauth.OAuth20Service;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import im.delight.android.webview.AdvancedWebView;

// Credit where credit is due:
// Mostly taken from 
// https://github.com/wuman/android-oauth-client/blob/6e01b81b7319a6954a1156e8b93c0b5cbeb61446/library/src/main/java/com/wuman/android/auth/DialogFragmentController.java

public class OAuthManagerFragmentController {
  private static final String TAG = "OAuthManager";

  private final android.app.FragmentManager fragmentManager;
  private final Handler uiHandler;

  private ReactContext context;
  private String providerName;
  private String authVersion;
  private OAuth10aService oauth10aService;
  private OAuth20Service oauth20Service;
  private String callbackUrl;
  private OAuth1RequestToken oauth1RequestToken;
  private HashMap<String,Object> mCfg;
  private AdvancedWebView mWebView;

  private Runnable onAccessToken;
  private OAuthManagerOnAccessTokenListener mListener;

  private void runOnMainThread(Runnable runnable) {
    uiHandler.post(runnable);
  }

  public OAuthManagerFragmentController(
    final ReactContext mReactContext,
    android.app.FragmentManager fragmentManager,
    final String providerName,
    OAuth10aService oauthService,
    final String callbackUrl
  ) {
    this.uiHandler = new Handler(Looper.getMainLooper());
    this.fragmentManager = fragmentManager;

    this.context = mReactContext;
    this.providerName = providerName;
    this.authVersion = "1.0";
    this.oauth10aService = oauthService;
    this.callbackUrl = callbackUrl;
  }

  public OAuthManagerFragmentController(
    final ReactContext mReactContext,
    android.app.FragmentManager fragmentManager,
    final String providerName,
    OAuth20Service oauthService,
    final String callbackUrl
  ) {
    this.uiHandler = new Handler(Looper.getMainLooper());
    this.fragmentManager = fragmentManager;

    this.context = mReactContext;
    this.providerName = providerName;
    this.authVersion = "2.0";
    this.oauth20Service = oauthService;
    this.callbackUrl = callbackUrl;
  }


  public void requestAuth(HashMap<String,Object> cfg, OAuthManagerOnAccessTokenListener listener) {
    mListener = listener;
    mCfg = cfg;

    runOnMainThread(new Runnable() {
      @Override
      public void run() {
        Log.d(TAG, "fragment manager checking...");
        if (fragmentManager.isDestroyed()) {
          return;
        }

        FragmentTransaction ft = fragmentManager.beginTransaction();
        Fragment prevDialog =
          fragmentManager.findFragmentByTag(TAG);
        
        Log.d(TAG, "previous() Dialog?");
        
        if (prevDialog != null) {
          ft.remove(prevDialog);
        }

        Log.d(TAG, "Creating new Fragment");
        OAuthManagerDialogFragment frag = 
          OAuthManagerDialogFragment.newInstance(context, OAuthManagerFragmentController.this);

        ft.setTransition(FragmentTransaction.TRANSIT_FRAGMENT_OPEN);
        ft.add(frag, TAG);
        Log.d(TAG, "Committing with State Loss");
        // ft.commit();
        ft.commitAllowingStateLoss();
      }
    });
  }

  private void dismissDialog() {
      runOnMainThread(new Runnable() {
          public void run() {
              OAuthManagerDialogFragment frag = 
                      (OAuthManagerDialogFragment) fragmentManager.findFragmentByTag(TAG);
                      
              if (frag != null) {
                  frag.dismissAllowingStateLoss();
              }
          }
      });
    }

  public void setRequestToken(
    final OAuth1RequestToken requestToken
  ) {
    this.oauth1RequestToken = requestToken;
  }

  public void loaded10aAccessToken(final OAuth1AccessToken accessToken) {
    Log.d(TAG, "Loaded access token in OAuthManagerFragmentController");
    Log.d(TAG, "AccessToken: " + accessToken + " (raw: " + accessToken.getRawResponse() + ")");

    mWebView = null;
    this.dismissDialog();
    mListener.onOAuth1AccessToken(accessToken);
  }

  public void loaded20AccessToken(final OAuth2AccessToken accessToken) {
    mWebView = null;
    this.dismissDialog();
    mListener.onOAuth2AccessToken(accessToken);
  }

  public void onComplete(String url) {
    Log.d(TAG, "onComplete called in fragment controller " + url);
    // if (mWebView != null) {
    //   this.getAccessToken(mWebView, url);
    // } else {
      // this.dismissDialog();
    // }
  }

  public void onError(int errorCode, String description, String failingUrl) {
    Log.e(TAG, "Error in OAuthManagerFragmentController: " + description);
    this.dismissDialog();
    mListener.onRequestTokenError(new Exception(description));
  }

  public void getRequestTokenUrlAndLoad(AdvancedWebView webView) {
    mWebView = webView;
    LoadRequestTokenTask task = new LoadRequestTokenTask(this, webView);
    task.execute();
  }

  public void getAccessToken(
    final AdvancedWebView webView, 
    final String url
  ) {
    Uri responseUri = Uri.parse(url);
    if (authVersion.equals("1.0")) {
      String oauthToken = responseUri.getQueryParameter("oauth_token");
      String oauthVerifier = responseUri.getQueryParameter("oauth_verifier");
      Load1AccessTokenTask task = new Load1AccessTokenTask(
        this, webView, oauth1RequestToken, oauthVerifier);
      task.execute();
    } else if (authVersion.equals("2.0")) {
      String code = responseUri.getQueryParameter("code");
      Log.d(TAG, "Called getAccessToken with code: " + code + " at " + url);
      if (code != null) {
        Load2AccessTokenTask task = new Load2AccessTokenTask(
          this, webView, code);
        task.execute();
      } else {
        this.dismissDialog();
        mListener.onRequestTokenError(new Exception("No token found"));
      }
    }
  }

  ////// TASKS

  private abstract class OAuthTokenTask<Result> 
                          extends AsyncTask<Void, Void, Result> {
    protected AdvancedWebView mWebView;
    protected OAuthManagerFragmentController mCtrl;

    public OAuthTokenTask(
      OAuthManagerFragmentController ctrl,
      AdvancedWebView webView
    ) {
      this.mCtrl = ctrl;
      this.mWebView = webView;
    }

    @Override
    protected Result doInBackground(Void... params) {
      return null;
    }

    @Override
    protected void onPostExecute(final Result result) {}
  }

  private class LoadRequestTokenTask extends OAuthTokenTask<String> {
    private OAuth1RequestToken oauth1RequestToken;

    public LoadRequestTokenTask(
      OAuthManagerFragmentController ctrl, 
      AdvancedWebView view
    ) {
      super(ctrl, view);
    }

    @Override
    protected String doInBackground(Void... params) {
      try {
        if (authVersion.equals("1.0")) {
          oauth1RequestToken = oauth10aService.getRequestToken();

          final String requestTokenUrl = 
            oauth10aService.getAuthorizationUrl(oauth1RequestToken);
          return requestTokenUrl;
        } else if (authVersion.equals("2.0")) {

          String authorizationUrl;

          if (mCfg.containsKey("authorization_url_params")) {
            final HashMap<String, String> additionalParams = new HashMap<String, String>();
            additionalParams.put("access_type", "offline");
            additionalParams.put("prompt", "consent");

            Map<String,String> authUrlMap = (Map) mCfg.get("authorization_url_params");
            if (authUrlMap != null) {
              if (authUrlMap.containsKey("access_type")) {
                additionalParams.put("access_type", (String) authUrlMap.get("access_type"));
              }
              if (authUrlMap.containsKey("prompt")) {
                additionalParams.put("prompt", (String) authUrlMap.get("prompt"));
              }
            }
            authorizationUrl = oauth20Service.getAuthorizationUrl(additionalParams);
          } else {
            authorizationUrl = oauth20Service.getAuthorizationUrl();
          }

          return authorizationUrl;
        } else {
          return null;
        }
      } catch (OAuthConnectionException ex) {
        Log.e(TAG, "OAuth connection exception: " + ex.getMessage());
        ex.printStackTrace();
        return null;
      } catch (IOException ex) {
        Log.e(TAG, "IOException occurred: "+ ex.getMessage());
        ex.printStackTrace();
        return null;
      }
    }

    @Override
    protected void onPostExecute(final String url) {
      runOnMainThread(new Runnable() {
        @Override
        public void run() {
          if (url == null) {
            mCtrl.onError(-1, "No url", "");
            return;
          }
          if (authVersion.equals("1.0")) {
            mCtrl.setRequestToken(oauth1RequestToken);
            mWebView.loadUrl(url);
          } else if (authVersion.equals("2.0")) {
            mWebView.loadUrl(url);
          }
        }
      });
    }
  }

  private class Load1AccessTokenTask extends OAuthTokenTask<OAuth1AccessToken> {
    private String oauthVerifier;

    public Load1AccessTokenTask(
      OAuthManagerFragmentController ctrl, 
      AdvancedWebView view,
      OAuth1RequestToken requestToken,
      String oauthVerifier
    ) {
      super(ctrl, view);
      this.oauthVerifier = oauthVerifier;
    }

    @Override
    protected OAuth1AccessToken doInBackground(Void... params) {
      try {
        final OAuth1AccessToken accessToken = 
          (OAuth1AccessToken) oauth10aService.getAccessToken(oauth1RequestToken, oauthVerifier);
        return accessToken;
      } catch (OAuthConnectionException ex) {
        Log.e(TAG, "OAuth connection exception: " + ex.getMessage());
        ex.printStackTrace();
        return null;
      } catch (IOException ex) {
        Log.e(TAG, "An exception occurred getRequestToken: " + ex.getMessage());
        ex.printStackTrace();
        return null;
      }
    }

    @Override
    protected void onPostExecute(final OAuth1AccessToken accessToken) {
      runOnMainThread(new Runnable() {
        @Override
        public void run() {
          if (accessToken == null) {
            mCtrl.onError(-1, "No accessToken found", "");
            return;
          }
          mCtrl.loaded10aAccessToken(accessToken);
        }
      });
    }
  }

  private class Load2AccessTokenTask extends OAuthTokenTask<OAuth2AccessToken> {
    private String authorizationCode;

    public Load2AccessTokenTask(
      OAuthManagerFragmentController ctrl, 
      AdvancedWebView view,
      String authorizationCode
    ) {
      super(ctrl, view);
      this.authorizationCode = authorizationCode;
    }

    @Override
    protected OAuth2AccessToken doInBackground(Void... params) {
      try {
        final OAuth2AccessToken accessToken =
            (OAuth2AccessToken) oauth20Service.getAccessToken(authorizationCode);
        return accessToken;
      } catch (OAuthConnectionException ex) {
        Log.e(TAG, "OAuth connection exception: " + ex.getMessage());
        ex.printStackTrace();
        return null;
      } catch (IOException ex) {
        Log.e(TAG, "An exception occurred getRequestToken: " + ex.getMessage());
        ex.printStackTrace();
        return null;
      }
    }

    @Override
    protected void onPostExecute(final OAuth2AccessToken accessToken) {
      runOnMainThread(new Runnable() {
        @Override
        public void run() {
          if (accessToken == null) {
            mCtrl.onError(-1, "No accessToken found", "");
            return;
          }
          mCtrl.loaded20AccessToken(accessToken);
        }
      });
    }
  }

  public String getCallbackUrl() {
    return this.callbackUrl;
  }
}
