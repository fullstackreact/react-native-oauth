# GITHUB

```
    import OAuthManager from 'react-native-oauth';

    const config = {
        github: {
            client_id: ClientID,
            client_secret: ClientSecret
        }
    }

    const manager = new OAuthManager('<your_aplication_name')

    export default function Login(){
        manager.configure(config)

        manager.addProvider({
            'github': {
                auth_version: '2.0',
                authorize_url: 'https://github.com/login/oauth/authorize',
                access_token_url: 'https://github.com/login/oauth/access_token',
                callback_url: ({github}) => `${github}://oauth`,
            }
        })

        manager.authorize('github')
            .then(resp => console.log(`Your request returned success:`, resp))
            .catch(err => console.log(`Your request returned error:`, err))

        return(
            <View>
                <Text>Hello friend!</Text>
            </View>
        )
    }

```