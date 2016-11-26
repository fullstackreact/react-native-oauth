package io.fullstack.oauth;

import java.lang.reflect.Type;
import android.content.Context;
import android.util.Log;
import java.util.Set;
import java.util.HashMap;
import android.content.Context;
import android.net.Uri;
import android.os.Handler;
import android.content.SharedPreferences;
import android.content.SharedPreferences.OnSharedPreferenceChangeListener;
import com.google.gson.Gson;
import android.text.TextUtils;
import java.util.Collection;

import com.github.scribejava.core.model.OAuth1AccessToken;
import com.github.scribejava.core.model.Token;
import com.google.gson.reflect.TypeToken;

public class OAuthManagerStore {
  private static final String TAG = "OAuthManagerStore";
  private static final String MAP_TAG = "CredentialList";
  // private static final Type MAP_TYPE = new TypeToken<HashMap<String, Credential>>() {}.getType();
  private static OAuthManagerStore oauthManagerStore;
  private Context context;

  private SharedPreferences prefs;
  private SharedPreferences.Editor editor;
  private OnSharedPreferenceChangeListener listener;

    public OAuthManagerStore(Context ctx) {
      this(ctx, TAG, Context.MODE_PRIVATE);
    }

    public OAuthManagerStore(Context ctx, String name) {
      this(ctx, name, Context.MODE_PRIVATE);
    }

    public OAuthManagerStore(Context ctx, String name, int mode) {
      // setup credential store
      this.context = ctx;
      this.prefs = ctx.getSharedPreferences(name, Context.MODE_PRIVATE);
      editor = this.prefs.edit();
      listener = new SharedPreferences.OnSharedPreferenceChangeListener() {
        @Override
        public void onSharedPreferenceChanged(SharedPreferences prefs, String key) {
          Log.d(TAG, "Preferences changed: " + key);
        }
      };
      prefs.registerOnSharedPreferenceChangeListener(listener);
    }

    public static OAuthManagerStore getOAuthManagerStore(Context ctx, String name, int mode) {
      if (oauthManagerStore == null) {
        oauthManagerStore = new OAuthManagerStore(ctx, name, mode);
      }
      return oauthManagerStore;
    }

    public void store(String providerName, final OAuth1AccessToken accessToken) {
      if (accessToken == null) {
        throw new IllegalArgumentException("Token is null");
      }
      if (providerName.equals("") || providerName == null) {
        throw new IllegalArgumentException("Provider is null");
      }
      editor.putString(providerName, new Gson().toJson(accessToken));
    }

    public void commit() {
      editor.commit();
    }

    public <T> T get(String providerName, Class<T> a) {
      String gson = this.prefs.getString(providerName, null);
      if (gson == null) {
        return null;
      } else {
        try {
          return new Gson().fromJson(gson, a);
        } catch (Exception ex) {
          throw new IllegalArgumentException("Object storaged with key " + providerName + " is instanceof other class");
        }
      }
    }

    public void delete(String providerName) {
      editor.remove(providerName);
      this.commit();
    }

    // private class CredentialList {
    //   private HashMap<String, Credential> _credentials;
    //   private SharedPreferences prefs; 
      
    //   public CredentialList(final SharedPreferences prefs) {
    //     this.prefs = prefs;
    //     _credentials = this.load();
    //   }

    //   public CredentialList add(String providerName, OAuth1AccessToken token) {
    //     Credential cred = new Credential(providerName, token);
    //     if (_credentials == null) {
    //       _credentials = this.load();
    //     }
    //     Log.d(TAG, "adding " + providerName + " = " + cred + " ( " + new Gson().toJson(cred) + ")");
    //     _credentials.put(providerName, cred);
    //     this.saveMap();
    //     return this;
    //   }

    //   public Set<String> keys() {
    //     return _credentials.keySet();
    //   }

    //   public Credential getCredentialFor(String providerName) {
    //     return _credentials.get(providerName);
    //   }

    //   public void delete(String providerName) {
    //     SharedPreferences.Editor editor = prefs.edit();
    //     editor.remove(providerName);
    //   }

    //   public void saveMap() {
    //     SharedPreferences.Editor editor = prefs.edit();
    //     editor.putString(MAP_TAG, new Gson().toJson(this._credentials));
    //     editor.commit();
    //     this.load();
    //   }

    //   public HashMap<String, Credential> load() {
    //     _credentials = new Gson().fromJson(prefs.getString(MAP_TAG, null), MAP_TYPE);
    //     return _credentials;
    //   }
    // }

    // private class Credential {
    //   private String providerName;
    //   private OAuth1AccessToken oauth1AccessToken;
    //   private String authVersion;

    //   public Credential(String providerName, OAuth1AccessToken token) {
    //     this.providerName = providerName;
    //     this.oauth1AccessToken = token;
    //     this.authVersion = "1.0";
    //   }

    //   public Token getToken() {
    //     if (authVersion.equals("1.0")) {
    //       return this.oauth1AccessToken;
    //     } else {
    //       return null;
    //     }
    //   }

    //   public Credential createInstance(Type type) {
    //     return new Credential()
    //   }
    // }
}