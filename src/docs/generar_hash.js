import bcrypt from 'bcryptjs';

async function generarHash() {
  const password = 'Admin1234';
  const hash = await bcrypt.hash(password, 10);
  console.log('Hash bcrypt válido:');
  console.log(hash);
}

generarHash();