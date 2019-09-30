import test from 'ava';
import AWS from 'aws-sdk';
import randomize from 'randomatic';
import { promise as searchUser } from '../../src/associate-consumer-cognito-search.js';
require('dotenv/config');

AWS.config.update({
  region: 'us-east-1'
});
const dynamoDB = new AWS.DynamoDB.DocumentClient();
const cognito = new AWS.CognitoIdentityServiceProvider();

const asyncGetUserPool = (userPoolName) => {
    return cognito.listUserPools({
        MaxResults: 60
      }).promise().then((data)=>{
        return data.UserPools.filter((userPool) => {
            return (userPool.Name.indexOf(userPoolName) > -1);
          })[0].Id;   
      });
  };

test.beforeEach(async (t) => {
 
  t.context.userPoolId =await  asyncGetUserPool('customer');

});

 test('should throw missing properties exception', async (t) => {
	  const response = await t.throws(searchUser({
		    body: JSON.stringify({
		    }),
		     requestContext: {
		        authorizer: {
		              sub: 'associateid',  
		              'custom:user_pool': 'associate',
		              'cognito:username': 'saml_TestAssociate'
		            },
		         identity: {
		              sourceIp: '127.0.0.1'
		            }
        		}
		  }));
	  t.deepEqual(response, {code: 'missing_properties',message: 'The following properties are missing, "username".',statusCode: 400});
});


test('should be successfull if user exists', async (t) => {
	let username = randomize('a', 15)
	let email = randomize('a', 8)
	let userPoolId =await  asyncGetUserPool('customer');
	const user = await cognito.adminCreateUser({
	    UserPoolId: userPoolId,
	    Username: username,
	    MessageAction: 'SUPPRESS',
	    UserAttributes: [{
		      Name: 'email',
		      Value: email+'@example.com'
		      },{
		      Name: 'custom:user_pool',
		      Value: 'customer'
	    	}]
  	}).promise().then((data) => data.User);

	const response = await (searchUser({
	    body: JSON.stringify({
	      username: username
	    }),
	    requestContext: {
	        authorizer: {
	          sub: 'associateid',  
	          'custom:user_pool': 'associate',
	          'cognito:username': 'saml_TestAssociate'
	        },
		    identity: {
		          sourceIp: '127.0.0.1'
		    }
	    }
  	}));
  	t.is(response, 'success');
  	//delete the created user
  	let params = {
					UserPoolId: userPoolId,
					Username: username
				};
  	let cognitoUserDeleted = await cognito.adminDeleteUser(params).promise()
		.catch(async function(err){
				console.log(err.stack);
				throw new Error('cognitoDeletionFailed');
	});;	
});

test('should throw error when user is not in cognito', async (t) => {
  let username = randomize('a', 15)
  const response = await t.throws(searchUser({
      body: JSON.stringify({
        username: username,
      }),
      requestContext: {
         authorizer: {
              sub: 'associateid',  
              'custom:user_pool': 'associate',
              'cognito:username': 'saml_TestAssociate'
            },
         identity: {
              sourceIp: '127.0.0.1'
            }
      }
    }));
  console.log('username '+username);
  console.log(response)
});