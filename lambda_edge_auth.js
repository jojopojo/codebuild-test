'use strict';

exports.handler = (event, context, callback) => {
    const request = event.Records[0].cf.request;
    const headers = request.headers;

    const authUser = 'secretuser'; // Replace with your username
    const authPass = 'secretpassword'; // Replace with your password

    const authString = 'Basic ' + new Buffer(authUser + ':' + authPass).toString('base64');

    if (typeof headers.authorization == 'undefined' || headers.authorization[0].value != authString) {
        const body = 'Unauthorized';
        const response = {
            status: '401',
            statusDescription: 'Unauthorized',
            body: body,
            headers: {
                'www-authenticate': [{key: 'WWW-Authenticate', value:'Basic'}]
            },
        };
        callback(null, response);
    }

    callback(null, request);
};