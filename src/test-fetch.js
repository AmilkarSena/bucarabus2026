import apiClient from '../api/client.js';

async function testFetch() {
  try {
    console.log('🔍 Probando fetch desde el cliente API...\n');
    
    const response = await apiClient.get('/drivers');
    
    console.log('📊 Status:', response.status);
    console.log('📊 Headers:', response.headers);
    console.log('📊 Data:', JSON.stringify(response.data, null, 2));
    
    console.log('\n✅ Fetch exitoso!');
    console.log(`Total de conductores: ${response.data.data?.length || 0}`);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error('Response:', error.response?.data);
  }
}

testFetch();
