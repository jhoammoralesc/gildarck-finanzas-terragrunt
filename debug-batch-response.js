// Debug script para verificar formato de respuesta batch-initiate
const API_BASE_URL = 'https://gslxbu791e.execute-api.us-east-1.amazonaws.com/dev';

async function debugBatchInitiate() {
    const token = 'eyJraWQiOiJPVXlSdyt1a2E4VEZjZHhZdWdsV205dzh1Mk5jSDVGXC9nbG42aGJWdWpubz0iLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJmNGY4OTQ4OC1jMDYxLTcwMWYtYWM2YS1mZTI2NjMyNWQ0MjMiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwiaXNzIjoiaHR0cHM6XC9cL2NvZ25pdG8taWRwLnVzLWVhc3QtMS5hbWF6b25hd3MuY29tXC91cy1lYXN0LTFfNlg1YXgzdkJKIiwiY29nbml0bzp1c2VybmFtZSI6Impob2Ftc2ViYXN0aWFubW9yYWxlc2NhcmRvbmEiLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJKaG9hbSBTZWJhc3RpYW4gTW9yYWxlcyBDYXJkb25hIiwib3JpZ2luX2p0aSI6IjY2NWMzZjIyLThhMTQtNDIwNi05NmFhLThjNmEzYzM1OGNkYiIsImF1ZCI6IjM5djZ0dGwzNmlpZXBpbTRrdDQ0MWU3OXFxIiwiZXZlbnRfaWQiOiJmMzlmOGQ1My0zZmQxLTRkYTItYjcwYy1jNzI0YzIxYjFmOGIiLCJ0b2tlbl91c2UiOiJpZCIsImF1dGhfdGltZSI6MTc2MTYwOTU5NCwibmFtZSI6Ikpob2FtIFNlYmFzdGlhbiBNb3JhbGVzIENhcmRvbmEiLCJleHAiOjE3NjE2MTMxOTQsImlhdCI6MTc2MTYwOTU5NCwianRpIjoiNzBmMzUzMGQtNmQwNi00Y2E3LThmZDQtYjM0MTQyZDVhNzU4IiwiZW1haWwiOiJtYW9oam1vcmFsZXM5MUBnbWFpbC5jb20ifQ.rsMSzcyu_0KRCEHsu9NdRje1fGSTB9qN9AON6_-sZZR5zIjHM3VQXJCrNznK2FOEy5872E7zST7BaZ23bGkmQBSO0rmIOr6MeQ3UGF6866rzWjD5rzn9vY5ZKfdioM2g28Zoe7kxHfDAW6hUoe7EgA96dlMuYpISJRArH3GJ5FHp_KRLLVO2Kg98ESWBwq_0HdB-OGL3xYUD_MpvJLAWA40b-IfkfEGcV9KpIKhCm9sMzMz5KertL6BIkz5LyUavLJUu6YnPS9OUsTC17S4NSAWv7HGRnIBcHAzPxK_mV5PiSgDHfcjCPYld46Uaxd-lM1mwZZIPGEFkD_qZvfalHA';
    
    const testFiles = [
        { filename: 'test1.jpg', content_type: 'image/jpeg', file_size: 1000 },
        { filename: 'test2.jpg', content_type: 'image/jpeg', file_size: 2000 }
    ];

    try {
        console.log('🔍 Testing batch-initiate response format...');
        
        const response = await fetch(`${API_BASE_URL}/upload/batch-initiate`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': token
            },
            body: JSON.stringify({ files: testFiles })
        });

        console.log('📊 Response Status:', response.status);
        console.log('📊 Response Headers:', Object.fromEntries(response.headers.entries()));
        
        const responseText = await response.text();
        console.log('📊 Raw Response Text:', responseText);
        
        try {
            const responseJson = JSON.parse(responseText);
            console.log('📊 Parsed JSON:', JSON.stringify(responseJson, null, 2));
            console.log('📊 masterBatchId extraction test:', responseJson.masterBatchId);
        } catch (parseError) {
            console.error('❌ JSON Parse Error:', parseError);
        }
        
    } catch (error) {
        console.error('❌ Request Error:', error);
    }
}

debugBatchInitiate();
