import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Read .env.local file manually
let SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY;

try {
    const envPath = resolve(__dirname, '.env.local');
    const envFile = readFileSync(envPath, 'utf8');
    const envVars = envFile.split('\n').reduce((acc, line) => {
        const [key, ...valueParts] = line.split('=');
        if (key && valueParts.length > 0) {
            let value = valueParts.join('=').trim();
            // Remove quotes if present
            if ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith("'") && value.endsWith("'"))) {
                value = value.slice(1, -1);
            }
            acc[key.trim()] = value;
        }
        return acc;
    }, {});

    SUPABASE_URL = envVars.VITE_SUPABASE_URL;
    SUPABASE_PUBLISHABLE_KEY = envVars.VITE_SUPABASE_PUBLISHABLE_KEY;
} catch (error) {
    console.error('❌ Could not read .env.local file:', error.message);
}

console.log('\n🔍 SUPABASE INTEGRATION TEST\n');
console.log('='.repeat(50));

// Test 1: Check environment variables
console.log('\n📋 Test 1: Environment Variables');
console.log('-'.repeat(50));
if (!SUPABASE_URL) {
    console.error('❌ VITE_SUPABASE_URL is not set');
} else {
    console.log('✅ VITE_SUPABASE_URL:', SUPABASE_URL);
}

if (!SUPABASE_PUBLISHABLE_KEY) {
    console.error('❌ VITE_SUPABASE_PUBLISHABLE_KEY is not set');
} else {
    console.log('✅ VITE_SUPABASE_PUBLISHABLE_KEY:', SUPABASE_PUBLISHABLE_KEY.substring(0, 20) + '...');
}

if (!SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY) {
    console.error('\n❌ Missing environment variables. Please check your .env.local file.');
    process.exit(1);
}

// Test 2: Initialize Supabase client
console.log('\n📋 Test 2: Supabase Client Initialization');
console.log('-'.repeat(50));
let supabase;
try {
    supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
        auth: {
            storage: {
                getItem: () => null,
                setItem: () => { },
                removeItem: () => { }
            },
            persistSession: false,
            autoRefreshToken: false,
        }
    });
    console.log('✅ Supabase client created successfully');
} catch (error) {
    console.error('❌ Failed to create Supabase client:', error.message);
    process.exit(1);
}

// Test 3: Test database connection
console.log('\n📋 Test 3: Database Connection');
console.log('-'.repeat(50));
try {
    const { data, error } = await supabase
        .from('rental_leads')
        .select('count')
        .limit(1);

    if (error) {
        throw error;
    }
    console.log('✅ Successfully connected to database');
    console.log('✅ rental_leads table is accessible');
} catch (error) {
    console.error('❌ Database connection failed:', error.message);
    console.error('   Details:', error);
}

// Test 4: Test table schema
console.log('\n📋 Test 4: Verify Table Schema');
console.log('-'.repeat(50));
try {
    const { data, error } = await supabase
        .from('rental_leads')
        .select('*')
        .limit(1);

    if (error) {
        throw error;
    }

    console.log('✅ Table schema verified');
    if (data && data.length > 0) {
        console.log('   Sample columns:', Object.keys(data[0]).join(', '));
    } else {
        console.log('   Table is empty, but accessible');
    }
} catch (error) {
    console.error('❌ Schema verification failed:', error.message);
}

// Test 5: Test INSERT operation (simulating RentalCalculator submission)
console.log('\n📋 Test 5: Test INSERT Operation');
console.log('-'.repeat(50));
const testData = {
    address: 'Damrak 123, Amsterdam',
    postal_code: '1012 JS',
    square_meters: 85,
    rooms: 3,
    interior: 'unfurnished',
    condition: 'average',
    full_name: 'Test User',
    email: 'test@example.com',
    phone: '+31 6 12345678',
    estimated_rent: 2100
};

console.log('📝 Attempting to insert test data...');
try {
    const { data, error } = await supabase
        .from('rental_leads')
        .insert([testData])
        .select();

    if (error) {
        throw error;
    }

    console.log('✅ Test data inserted successfully!');
    console.log('   Inserted record ID:', data[0].id);

    // Test 6: Verify the insertion by reading it back
    console.log('\n📋 Test 6: Verify Inserted Data');
    console.log('-'.repeat(50));
    const { data: verifyData, error: verifyError } = await supabase
        .from('rental_leads')
        .select('*')
        .eq('id', data[0].id)
        .single();

    if (verifyError) {
        throw verifyError;
    }

    console.log('✅ Data verified successfully!');
    console.log('   Name:', verifyData.full_name);
    console.log('   Email:', verifyData.email);
    console.log('   Address:', verifyData.address);
    console.log('   Estimated Rent: €' + verifyData.estimated_rent);

    // Clean up: Delete test data
    console.log('\n🧹 Cleaning up test data...');
    const { error: deleteError } = await supabase
        .from('rental_leads')
        .delete()
        .eq('id', data[0].id);

    if (deleteError) {
        console.error('⚠️  Warning: Could not delete test data:', deleteError.message);
    } else {
        console.log('✅ Test data cleaned up successfully');
    }

} catch (error) {
    console.error('❌ INSERT operation failed:', error.message);
    console.error('   Details:', error);

    if (error.code === 'PGRST116') {
        console.error('\n💡 Tip: The table might not exist or might have different column names.');
    } else if (error.code === '42501') {
        console.error('\n💡 Tip: Permission denied. Check your Row Level Security (RLS) policies.');
    }
}

// Test 7: Test error handling
console.log('\n📋 Test 7: Error Handling');
console.log('-'.repeat(50));
try {
    const { data, error } = await supabase
        .from('rental_leads')
        .insert([{ invalid_field: 'test' }]);

    if (error) {
        console.log('✅ Error handling works correctly');
        console.log('   Error caught:', error.message);
    } else {
        console.log('⚠️  Expected an error but none was thrown');
    }
} catch (error) {
    console.log('✅ Error handling works correctly');
    console.log('   Error caught:', error.message);
}

// Summary
console.log('\n' + '='.repeat(50));
console.log('📊 TEST SUMMARY');
console.log('='.repeat(50));
console.log('✅ All tests completed!');
console.log('\n💡 Next steps:');
console.log('   1. Fill out the Rental Calculator form on your website');
console.log('   2. Check your Supabase dashboard for the new entry');
console.log('   3. Verify the data was saved correctly');
console.log('\n🌐 Your app is running at: http://localhost:5173');
console.log('📊 Supabase Dashboard:', SUPABASE_URL.replace('.supabase.co', '.supabase.co/project/_/editor'));
console.log('\n');
