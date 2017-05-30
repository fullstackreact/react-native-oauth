package com.github.scribejava.apis;

import android.util.Log;

import com.github.scribejava.core.builder.api.DefaultApi20;
import com.github.scribejava.core.extractors.OAuth2AccessTokenExtractor;
import com.github.scribejava.core.extractors.TokenExtractor;
import com.github.scribejava.core.model.OAuth2AccessToken;
import com.github.scribejava.core.model.Verb;

public class ConfigurableApi extends DefaultApi20 {

    private String accessTokenEndpoint;

    private String authorizationBaseUrl;

    private Verb accessTokenVerb = Verb.GET;

    protected ConfigurableApi() {
    }

    private static class InstanceHolder {
        private static final ConfigurableApi INSTANCE = new ConfigurableApi();
    }

    public static ConfigurableApi instance() {
        return InstanceHolder.INSTANCE;
    }

    public ConfigurableApi setAccessTokenEndpoint(String endpoint) {
        accessTokenEndpoint = endpoint;
        return this;
    }

    public ConfigurableApi setAuthorizationBaseUrl(String baseUrl) {
        authorizationBaseUrl = baseUrl;
        return this;
    }

    public ConfigurableApi setAccessTokenVerb(String verb) {
        if (verb.equalsIgnoreCase("GET")) {
            accessTokenVerb = Verb.GET;
        } else if (verb.equalsIgnoreCase("POST")) {
            accessTokenVerb = Verb.POST;
        } else {
            Log.e("ConfigurableApi", "Expected GET or POST string values for accessTokenVerb.");
        }

        return this;
    }

    @Override
    public Verb getAccessTokenVerb() {
        return accessTokenVerb;
    }

    @Override
    public String getAccessTokenEndpoint() {
        return accessTokenEndpoint;
    }

    @Override
    protected String getAuthorizationBaseUrl() {
        return authorizationBaseUrl;
    }
}
