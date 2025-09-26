const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs'); // Import bcrypt

async function createConnection() {
    try {
        const connection = await mysql.createConnection({
            host: '127.0.0.1',
            user: 'root',
            password: 'root',
            database: 'interphoneapp_database',
            port: 3307
        });

        console.log('✅ Conectat la baza de date MySQL!');
        return connection;
    } catch (error) {
        console.error('❌ Eroare la conectarea la MySQL:', error);
        throw error;
    }
}

// Funcție pentru hash-ing parole
async function hashPassword(password) {
    const salt = await bcrypt.genSalt(10);
    return await bcrypt.hash(password, salt);
}

// Funcție pentru compararea parolelor
async function comparePassword(inputPassword, storedPassword) {
    return await bcrypt.compare(inputPassword, storedPassword);
}

module.exports = { createConnection, hashPassword, comparePassword };