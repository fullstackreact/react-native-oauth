import invariant from 'invariant';
import {Type, String} from 'valib';

const notEmpty = (str) => Type.isString(str) && !String.isEmpty(str) || 'cannot be empty';

const isValid = (prop, str, validations=[]) => {
  return validations
          .map(fn => {
            const val = fn(str);
            invariant(typeof val === 'boolean', `${prop} ${val}`)
          });
}
const withDefaultValidations = (validations) => Object.assign({}, {
  callback_url: [notEmpty]
}, validations);

const validate = (customValidations={}) => (props) => {
  const validations = withDefaultValidations(customValidations);
  return Object.keys(props)
        .map(property => isValid(property, props[property], validations[property]));
}

export const authProviders = {
  'twitter': {
    auth_version: "1.0",
    request_token_url: 'https://api.twitter.com/oauth/request_token',
    authorize_url: 'https://api.twitter.com/oauth/authorize',
    access_token_url: 'https://api.twitter.com/oauth/access_token',
    api_url: 'https://api.twitter.com',
    callback_url: ({app_name}) => `${app_name}://oauth-response/twitter`,

    validate: validate({
      consumer_key: [notEmpty],
      consumer_secret: [notEmpty]
    })
  },
  'facebook': {
    auth_version: "2.0",
    authorize_url: 'https://graph.facebook.com/oauth/authorize',
    api_url: 'https://graph.facebook.com',
    callback_url: ({client_id}) => `fb${client_id}://authorize`,

    validate: validate({
      client_id: [notEmpty],
      client_secret: [notEmpty]
    })
  },
  'google': {
    auth_version: "2.0",
    authorize_url: 'https://accounts.google.com/o/oauth2/auth',
    access_token_url: 'https://accounts.google.com/o/oauth2/token',
    callback_url: ({app_name}) => `${app_name}://oauth-response`,
    validate: validate()
  },
  'github': {
    auth_version: '2.0',
    authorize_url: 'https://github.com/login/oauth/authorize',
    access_token_url: 'https://github.com/login/oauth/access_token',
    api_url: 'https://api.github.com',
    callback_url: ({app_name}) => `${app_name}://oauth`,
    validate: validate()
  },
  'slack': {
    auth_version: '2.0',
    authorize_url: 'https://slack.com/oauth/authorize',
    access_token_url: 'https://slack.com/api/oauth.access',
    api_url: 'https://slack.com/api',
    callback_url: ({app_name}) => `${app_name}://oauth`,
    defaultParams: {
      token: 'access_token'
    },
    validate: validate({
      client_id: [notEmpty],
      client_secret: [notEmpty]
    })
  },
  'spotify': {
    auth_version: "2.0",
    authorize_url: 'https://accounts.spotify.com/authorize',
    api_url: 'https://api.spotify.com/',
    callback_url: ({app_name}) => `${app_name}://authorize`,

    validate: validate({
      client_id: [notEmpty],
      client_secret: [notEmpty]
    })
  },
}

export default authProviders;
