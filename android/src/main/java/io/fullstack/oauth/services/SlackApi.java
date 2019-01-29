package com.github.scribejava.apis;

import android.util.Log;

import com.github.scribejava.core.builder.api.DefaultApi20;
import com.github.scribejava.core.extractors.OAuth2AccessTokenExtractor;
import com.github.scribejava.core.extractors.TokenExtractor;
import com.github.scribejava.core.model.OAuth2AccessToken;
import com.github.scribejava.core.model.Verb;

public class SlackApi extends DefaultApi20 {

    protected SlackApi() {
    }

    private static class InstanceHolder {
        private static final SlackApi INSTANCE = new SlackApi();
    }

    public static SlackApi instance() {
        return InstanceHolder.INSTANCE;
    }

    @Override
    public Verb getAccessTokenVerb() {
        return Verb.GET;
    }

    @Override
    public String getAccessTokenEndpoint() {
        return "https://slack.com/api/oauth.access";
    }

    @Override
    protected String getAuthorizationBaseUrl() {
        return "https://slack.com/oauth/authorize";
    }
}