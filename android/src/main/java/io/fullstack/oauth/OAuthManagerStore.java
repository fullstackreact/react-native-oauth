package io.fullstack.oauth;

import android.util.Log;
import android.content.Context;
import android.net.Uri;
import android.os.Handler;
import android.content.SharedPreferences;
import com.google.gson.Gson;
// import com.google.gson.reflect.TypeToken;

public class OAuthManagerStore {
    private final SharedPreferences prefs;

    public OAuthManagerStore(Context ctx, String name) {
      // setup credential store
    this.prefs = 
      ctx.getSharedPreferences(name, Context.MODE_PRIVATE); 
    }

    public void store(String name) {
      // TODO
    }

    public void load(String name) {

    }
}