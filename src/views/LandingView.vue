<template>
  <div class="landing-page">
    <!-- ═══ HEADER ═══ -->
    <header class="landing-header">
      <div class="header-container">
        <div class="logo" @click="goToHome" style="cursor:pointer">
          <span class="logo-icon">🚌</span>
          <span class="logo-text">BucaraBus</span>
        </div>
        <nav class="nav-menu">
          <button @click="scrollTo('features')">Características</button>
          <button @click="scrollTo('how-it-works')">Cómo Funciona</button>
          <button @click="scrollTo('testimonials')">Clientes</button>
          <button @click="scrollTo('contact')">Contacto</button>
          <button @click="scrollTo('footer')">Legal</button>
        </nav>
        <div class="header-actions">
          <div v-if="authStore.isAuthenticated" class="user-badge">
            <span class="user-avatar-small">{{ authStore.userAvatar }}</span>
            <span class="user-name-small">{{ authStore.userName }}</span>
            <button class="btn-logout-small" @click="handleLogout" title="Cerrar sesión">🚪</button>
          </div>
          <template v-if="!authStore.isAuthenticated">
            <button class="btn-ghost" @click="goToLogin">Iniciar Sesión</button>
          </template>
          <button v-if="authStore.isAuthenticated" class="btn-accent" @click="goToMonitor">
            {{ buttonText }} →
          </button>
        </div>
        <button class="mobile-menu-btn" @click="toggleMobileMenu">☰</button>
      </div>
    </header>

    <!-- ═══ MOBILE MENU OVERLAY ═══ -->
    <div class="mobile-menu-overlay" :class="{ 'open': isMobileMenuOpen }">
      <button class="mobile-close-btn" @click="toggleMobileMenu">✕</button>
      <nav class="mobile-nav-links">
        <button @click="scrollTo('features'); toggleMobileMenu()">Características</button>
        <button @click="scrollTo('how-it-works'); toggleMobileMenu()">Cómo Funciona</button>
        <button @click="scrollTo('testimonials'); toggleMobileMenu()">Clientes</button>
        <button @click="scrollTo('contact'); toggleMobileMenu()">Contacto</button>
        <button @click="scrollTo('footer'); toggleMobileMenu()">Legal</button>
        <div class="mobile-auth-links" v-if="!authStore.isAuthenticated">
          <button class="btn-ghost" @click="goToLogin">Iniciar Sesión</button>
        </div>
      </nav>
    </div>

    <!-- ═══ HERO ═══ -->
    <section class="hero-section">
      <div class="hero-bg-grid"></div>
      <div class="hero-glow hero-glow-1"></div>
      <div class="hero-glow hero-glow-2"></div>
      <div class="hero-container">
        <div class="hero-text fade-up">
          <div class="hero-badge">
            <span class="badge-dot"></span>
            🚀 Sistema en Producción · Bucaramanga, Colombia
          </div>
          <h1 class="hero-title">
            Gestión Inteligente de<br>
            <span class="gradient-text">Transporte Urbano</span>
          </h1>
          <p class="hero-subtitle">
            Monitorea en tiempo real tu flota de buses, optimiza rutas y mejora la experiencia de tus pasajeros con nuestra plataforma integral basada en GPS y WebSocket.
          </p>
          <div class="hero-actions">
            <button class="btn-hero-primary" @click="goToMonitor">
              {{ monitorButtonText }}
            </button>
            <button class="btn-hero-secondary" @click="goToPassengerApp">
              📱 Ver Demo
            </button>
          </div>
          <div class="trusted-strip">
            <span class="trusted-label">Usado por:</span>
            <div class="trusted-logos">
              <span class="trust-logo">🚌 Metrolínea</span>
              <span class="trust-logo">🚍 Cotraoriente</span>
              <span class="trust-logo">🚐 Cotrander</span>
            </div>
          </div>
        </div>
        <div class="hero-mockup fade-up-delay">
          <div class="mockup-window">
            <div class="mockup-titlebar">
              <span class="tb-dot red"></span>
              <span class="tb-dot yellow"></span>
              <span class="tb-dot green"></span>
              <span class="tb-title">BucaraBus · Monitor en Vivo</span>
            </div>
            <div class="mockup-body">
              <div class="mini-map">
                <div class="map-grid"></div>
                <div class="bus-pin pin-1"><div class="pin-circle">🚌</div><div class="pin-label">4568</div><div class="pin-pulse"></div></div>
                <div class="bus-pin pin-2"><div class="pin-circle">🚌</div><div class="pin-label">1234</div><div class="pin-pulse"></div></div>
                <div class="bus-pin pin-3"><div class="pin-circle">🚌</div><div class="pin-label">8821</div><div class="pin-pulse"></div></div>
                <div class="map-route route-1"></div>
                <div class="map-route route-2"></div>
              </div>
              <div class="mockup-stats">
                <div class="mstat"><div class="mstat-num">12</div><div class="mstat-lbl">Buses activos</div></div>
                <div class="mstat-sep"></div>
                <div class="mstat"><div class="mstat-num">4</div><div class="mstat-lbl">Rutas en línea</div></div>
                <div class="mstat-sep"></div>
                <div class="mstat"><div class="mstat-num live">🟢 LIVE</div><div class="mstat-lbl">WebSocket</div></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ═══ STATS ═══ -->
    <section class="stats-section" ref="statsSection">
      <div class="stats-container">
        <div class="stat-item"><div class="stat-number counter" data-target="24">0</div><div class="stat-unit">/7</div><div class="stat-label">Monitoreo continuo</div></div>
        <div class="stat-divider"></div>
        <div class="stat-item"><div class="stat-number counter" data-target="100">0</div><div class="stat-unit">%</div><div class="stat-label">Datos en tiempo real</div></div>
        <div class="stat-divider"></div>
        <div class="stat-item"><div class="stat-number counter" data-target="50">0</div><div class="stat-unit">+</div><div class="stat-label">Rutas configuradas</div></div>
        <div class="stat-divider"></div>
        <div class="stat-item"><div class="stat-number counter" data-target="99">0</div><div class="stat-unit">%</div><div class="stat-label">Disponibilidad</div></div>
      </div>
    </section>

    <!-- FEATURES SECTION -->
    <section id="features" class="features-section">
      <div class="section-container">
        <div class="section-header scroll-reveal">
          <div class="section-badge">Funcionalidades</div>
          <h2 class="section-title">Todo lo que tu flota necesita</h2>
          <p class="section-subtitle">Herramientas profesionales diseñadas para gestores de transporte urbano</p>
        </div>
        <div class="features-grid">
          <div class="feature-card scroll-reveal" v-for="(feat, i) in features" :key="i" :style="`--delay: ${i * 0.08}s`">
            <div class="feature-icon-wrap" :style="`background: ${feat.bg}`">
              <span class="feature-icon">{{ feat.icon }}</span>
            </div>
            <h3>{{ feat.title }}</h3>
            <p>{{ feat.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ═══ HOW IT WORKS ═══ -->
    <section id="how-it-works" class="how-section">
      <div class="section-container">
        <div class="section-header scroll-reveal">
          <div class="section-badge">Proceso</div>
          <h2 class="section-title">En marcha en minutos</h2>
          <p class="section-subtitle">Sin instalaciones complejas, sin hardware propietario</p>
        </div>
        <div class="steps-track">
          <div class="step scroll-reveal" v-for="(step, i) in steps" :key="i" :style="`--delay: ${i * 0.15}s`">
            <div class="step-connector" v-if="i < steps.length - 1"></div>
            <div class="step-circle"><span class="step-num">{{ i + 1 }}</span></div>
            <div class="step-body">
              <div class="step-icon">{{ step.icon }}</div>
              <h3>{{ step.title }}</h3>
              <p>{{ step.desc }}</p>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ═══ TESTIMONIOS ═══ -->
    <section id="testimonials" class="testimonials-section">
      <div class="section-container">
        <div class="section-header scroll-reveal">
          <div class="section-badge">Clientes</div>
          <h2 class="section-title">Lo que dicen nuestros operadores</h2>
        </div>
        <div class="testimonials-grid">
          <div class="testimonial-card scroll-reveal" v-for="(t, i) in testimonials" :key="i" :style="`--delay: ${i * 0.12}s`">
            <div class="stars">★★★★★</div>
            <p class="testimonial-text">"{{ t.text }}"</p>
            <div class="testimonial-author">
              <div class="author-avatar">{{ t.avatar }}</div>
              <div><div class="author-name">{{ t.name }}</div><div class="author-role">{{ t.role }}</div></div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ═══ CONTACT ═══ -->
    <section id="contact" class="contact-section">
      <div class="section-container">
        <div class="section-header scroll-reveal">
          <div class="section-badge">Contacto</div>
          <h2 class="section-title">Estamos para ayudarte</h2>
          <p class="section-subtitle">¿Tienes dudas o necesitas una demo personalizada para tu empresa?</p>
        </div>
        <div class="contact-grid">
          <div class="contact-info scroll-reveal">
            <div class="contact-card">
              <div class="contact-icon">📧</div>
              <div class="contact-details">
                <h4>Correo Electrónico</h4>
                <p>soporte@bucarabus.com</p>
              </div>
            </div>
            <div class="contact-card">
              <div class="contact-icon">📱</div>
              <div class="contact-details">
                <h4>WhatsApp / Teléfono</h4>
                <p>+57 300 123 4567</p>
              </div>
            </div>
            <div class="contact-card">
              <div class="contact-icon">📍</div>
              <div class="contact-details">
                <h4>Ubicación</h4>
                <p>Bucaramanga, Santander, CO</p>
              </div>
            </div>
          </div>
          <div class="contact-form-wrap scroll-reveal">
            <form class="landing-form" @submit.prevent>
              <div class="form-row">
                <input type="text" placeholder="Nombre completo" required />
              </div>
              <div class="form-row">
                <input type="email" placeholder="Correo electrónico" required />
              </div>
              <div class="form-row">
                <textarea placeholder="¿En qué podemos ayudarte?" rows="4" required></textarea>
              </div>
              <button type="submit" class="btn-hero-primary" style="width: 100%">Enviar Mensaje →</button>
            </form>
          </div>
        </div>
      </div>
    </section>

    <!-- ═══ CTA ═══ -->
    <section id="cta" class="cta-section scroll-reveal">
      <div class="cta-glow"></div>
      <div class="cta-content">
        <div class="cta-badge">¿Listo para empezar?</div>
        <h2>Transforma tu operación hoy</h2>
        <p>Únete a las empresas de Bucaramanga que ya digitalizaron su flota</p>
        <div class="cta-actions">
          <button class="btn-cta-primary" @click="goToMonitor">🚀 Acceder al Sistema</button>
          <button class="btn-cta-secondary" @click="goToLogin">Iniciar Sesión</button>
        </div>
        <p class="cta-note">Sin tarjeta de crédito · Configuración en minutos · Soporte incluido</p>
      </div>
    </section>

    <!-- ═══ FOOTER ═══ -->
    <footer id="footer" class="landing-footer">
      <div class="footer-container">
        <div class="footer-brand">
          <div class="footer-logo">🚌 BucaraBus</div>
          <p>Sistema de Gestión de Transporte Urbano para Bucaramanga y el Área Metropolitana.</p>
          <div class="footer-badges">
            <span class="fbadge">🔒 Seguro</span>
            <span class="fbadge">⚡ Tiempo Real</span>
            <span class="fbadge">📱 Multi-dispositivo</span>
          </div>
        </div>
        <div class="footer-links">
          <div class="footer-col"><h4>Producto</h4><button @click="scrollTo('features')">Características</button><button @click="scrollTo('how-it-works')">Cómo Funciona</button><button @click="goToMonitor">Acceder</button></div>
          <div class="footer-col"><h4>Plataforma</h4><a href="#">Monitor GPS</a><a href="#">Gestión de Flota</a><a href="#">App Conductor</a></div>
          <div class="footer-col"><h4>Contacto & Soporte</h4><a href="mailto:soporte@bucarabus.com">soporte@bucarabus.com</a><a href="tel:+573000000000">+57 300 000 0000</a><a href="#">Documentación</a></div>
        </div>
      </div>
      <div class="footer-bottom">
        <p>&copy; 2026 BucaraBus. Todos los derechos reservados.</p>
        <div class="footer-bottom-links">
          <a href="#" @click.prevent="openLegalModal('terms')">Términos</a>
          <a href="#" @click.prevent="openLegalModal('privacy')">Privacidad</a>
          <a href="#" @click.prevent="openLegalModal('cookies')">Cookies</a>
        </div>
      </div>
    </footer>

    <!-- Componente Modal Legal (Separado) -->
    <LegalModal v-model="showLegalModal" :section="legalSection" />
  </div>
</template>

<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import LegalModal from '../components/modals/LegalModal.vue'

const router = useRouter()
const authStore = useAuthStore()
const statsSection = ref(null)

// ── Estado de Menú Móvil ──────────────────────────────────────────
const isMobileMenuOpen = ref(false)
const toggleMobileMenu = () => isMobileMenuOpen.value = !isMobileMenuOpen.value

// ── Estado de Modales Legales ─────────────────────────────────────
const showLegalModal = ref(false)
const legalSection = ref('terms')

const openLegalModal = (section) => {
  legalSection.value = section
  showLegalModal.value = true
}

// ── Datos estáticos ──────────────────────────────────────────────
const features = [
  { icon: '📍', title: 'Seguimiento GPS', desc: 'Rastrea la ubicación exacta de cada bus con precisión en tiempo real mediante WebSocket.', bg: 'rgba(102,126,234,.12)' },
  { icon: '🗺️', title: 'Gestión de Rutas', desc: 'Crea, edita y optimiza rutas con herramientas visuales Leaflet intuitivas.', bg: 'rgba(16,185,129,.12)' },
  { icon: '👨‍✈️', title: 'Control de Conductores', desc: 'Administra tu equipo, asignaciones de buses y turnos desde un panel centralizado.', bg: 'rgba(245,158,11,.12)' },
  { icon: '🚌', title: 'Gestión de Flota', desc: 'Controla documentación, mantenimiento y estado operativo de cada vehículo.', bg: 'rgba(239,68,68,.12)' },
  { icon: '📊', title: 'Analytics en Tiempo Real', desc: 'Visualiza estadísticas de viajes, progreso de ruta y viajes completados al instante.', bg: 'rgba(139,92,246,.12)' },
  { icon: '🔔', title: 'Alertas Inteligentes', desc: 'Notificaciones automáticas de documentos por vencer, buses inactivos y eventos críticos.', bg: 'rgba(6,182,212,.12)' },
  { icon: '📅', title: 'Programación de Turnos', desc: 'Planifica horarios con validación automática de conflictos y disponibilidad.', bg: 'rgba(251,191,36,.12)' },
  { icon: '🌐', title: 'Acceso Multiplataforma', desc: 'Web, móvil y tablet. App dedicada para conductores con GPS integrado.', bg: 'rgba(236,72,153,.12)' },
]

const steps = [
  { icon: '🚌', title: 'Registra tu Flota', desc: 'Agrega buses con código AMB, conductores y define tus rutas con el editor visual.' },
  { icon: '📡', title: 'Activa el Monitoreo', desc: 'Los conductores abren la app, activan el GPS y aparecen en el mapa en segundos.' },
  { icon: '📊', title: 'Gestiona y Optimiza', desc: 'El monitor en vivo te da todo el contexto para tomar decisiones en tiempo real.' },
]

const testimonials = [
  { avatar: '👨‍💼', name: 'Carlos Rueda', role: 'Gerente Operativo · Metrolínea', text: 'BucaraBus transformó cómo gestionamos nuestra flota. El monitoreo GPS en tiempo real nos permitió reducir los tiempos muertos en un 30%.' },
  { avatar: '👩‍💼', name: 'Laura Gómez', role: 'Coordinadora de Rutas · Cotraoriente', text: 'La programación de turnos y la detección de conflictos nos ahorran horas de trabajo manual cada semana. Muy recomendado.' },
  { avatar: '👨‍🔧', name: 'Andrés Morales', role: 'Supervisor de Flota · Cotrander', text: 'Las alertas de documentos por vencer nos han evitado más de un problema legal. La plataforma es intuitiva y confiable.' },
]

// ── Router / Auth ────────────────────────────────────────────────
const buttonText = computed(() => {
  if (authStore.isAuthenticated) {
    const role = authStore.userRole
    if (role === 'driver') return 'Ir a App Conductor'
    if (role === 'passenger') return 'Ir a App Pasajero'
    return 'Ir al Dashboard'
  }
  return 'Acceder al Sistema'
})

const goToMonitor = () => {
  if (authStore.isAuthenticated) {
    const role = authStore.userRole
    if (role === 'driver') {
      window.location.href = window.location.origin + '/conductor/'
    } else if (role === 'passenger') {
      window.location.href = window.location.origin + '/pasajero/'
    } else {
      router.push('/monitor')
    }
  } else {
    router.push('/login')
  }
}
const goToLogin = () => router.push('/login')
const goToRegister = () => router.push('/register')
const goToPassengerApp = () => {
  const isLocal = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
  const url = isLocal
    ? `${window.location.protocol}//${window.location.hostname}:3004`
    : `${window.location.origin}/pasajero`
  window.open(url, '_blank')
}

// Botón temporal para abrir el simulador
const goToSimulator = () => {
  const isLocal = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
  const url = isLocal
    ? `${window.location.protocol}//${window.location.hostname}:3002/admin/simulator.html`
    : `${window.location.origin}/admin/simulator.html`
  window.open(url, '_blank')
}
const scrollTo = (id) => document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' })
const goToHome = () => {
  if (router.currentRoute.value.path === '/') {
    window.scrollTo({ top: 0, behavior: 'smooth' })
  } else {
    router.push('/')
  }
}
const scrollToTop = () => window.scrollTo({ top: 0, behavior: 'smooth' })
const scrollToFeatures = () => scrollTo('features')
const handleLogout = async () => {
  if (confirm('¿Cerrar sesión?')) { await authStore.logout(); window.location.reload() }
}

// ── Scroll Animations ────────────────────────────────────────────
let scrollObserver = null
let statsObserver = null
let countersStarted = false

const startCounters = () => {
  if (countersStarted) return
  countersStarted = true
  document.querySelectorAll('.counter').forEach(el => {
    const target = parseInt(el.dataset.target, 10)
    const step = Math.ceil(target / (1800 / 16))
    let current = 0
    const timer = setInterval(() => {
      current = Math.min(current + step, target)
      el.textContent = current
      if (current >= target) clearInterval(timer)
    }, 16)
  })
}

onMounted(() => {
  scrollObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible')
        scrollObserver.unobserve(entry.target)
      }
    })
  }, { threshold: 0.12 })
  document.querySelectorAll('.scroll-reveal, .fade-up, .fade-up-delay').forEach(el => scrollObserver.observe(el))

  statsObserver = new IntersectionObserver((entries) => {
    if (entries[0].isIntersecting) startCounters()
  }, { threshold: 0.5 })
  if (statsSection.value) statsObserver.observe(statsSection.value)
})

onUnmounted(() => {
  scrollObserver?.disconnect()
  statsObserver?.disconnect()
})
</script>

<style scoped>
/* ═══════════════ BASE ═══════════════ */
.landing-page {
  --primary: #667eea;
  --primary-dark: #5a67d8;
  --secondary: #764ba2;
  --accent: #f59e0b;
  --success: #10b981;
  --dark: #0f172a;
  --dark-mid: #1e293b;
  --gray: #64748b;
  --light: #f8fafc;
  --white: #ffffff;
  --radius: 16px;
  width: 100%;
  min-height: 100vh;
  background: var(--white);
  overflow-x: hidden;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
}

/* ═══════════════ ANIMATIONS ═══════════════ */
.fade-up.visible, .fade-up-delay.visible, .scroll-reveal.visible { opacity: 1; transform: none; }

/* Forzar visibilidad en móviles por si falla el IntersectionObserver */
@media (max-width: 1024px) {
  .fade-up, .scroll-reveal, .fade-up-delay {
    opacity: 1 !important;
    transform: none !important;
    transition: none !important;
  }
}

/* ═══ HEADER ═══ */
.landing-header { position: fixed; top: 0; left: 0; right: 0; z-index: 1000; background: rgba(255,255,255,0.92); backdrop-filter: blur(16px); border-bottom: 1px solid #e2e8f0; padding: 0.875rem 0; }
.header-container { max-width: 1200px; margin: 0 auto; padding: 0 2rem; display: flex; justify-content: space-between; align-items: center; gap: 2rem; }
.logo { display: flex; align-items: center; gap: 0.5rem; }
.logo-icon { font-size: 1.6rem; }
.logo-text { font-size: 1.25rem; font-weight: 800; color: var(--dark); letter-spacing: -0.5px; }
.nav-menu { display: flex; gap: 2rem; align-items: center; }
.nav-menu a, .nav-menu button { text-decoration: none; color: var(--gray); font-size: 0.9rem; font-weight: 500; transition: color 0.2s; background: none; border: none; cursor: pointer; padding: 0; font-family: inherit; }
.nav-menu a:hover, .nav-menu button:hover { color: var(--primary); }
.header-actions { display: flex; gap: 0.75rem; align-items: center; }
.btn-ghost { background: transparent; color: var(--gray); border: 1.5px solid #e2e8f0; padding: 0.6rem 1.2rem; border-radius: 10px; font-weight: 600; font-size: 0.875rem; cursor: pointer; transition: all 0.2s; }
.btn-ghost:hover { border-color: var(--primary); color: var(--primary); }
.btn-accent { background: var(--dark); color: white; border: none; padding: 0.6rem 1.2rem; border-radius: 10px; font-weight: 600; font-size: 0.875rem; cursor: pointer; transition: all 0.25s; }
.btn-accent:hover { background: var(--primary); transform: translateY(-1px); box-shadow: 0 6px 20px rgba(102,126,234,.35); }
.user-badge { display: flex; align-items: center; gap: 0.5rem; background: rgba(102,126,234,.08); padding: 0.4rem 0.9rem; border-radius: 20px; border: 1.5px solid var(--primary); }
.user-avatar-small { font-size: 1.1rem; }
.user-name-small { font-weight: 600; color: var(--primary); font-size: 0.875rem; }
.btn-logout-small { background: rgba(239,68,68,.1); border: none; color: #dc2626; padding: 0.2rem 0.5rem; border-radius: 6px; cursor: pointer; transition: all 0.2s; }
.btn-logout-small:hover { background: rgba(239,68,68,.2); }

/* ═══ HERO ═══ */
.hero-section { position: relative; overflow: hidden; background: var(--dark); padding: 6rem 2rem 5rem; min-height: 90vh; display: flex; align-items: center; margin-top: 62px; }
.hero-bg-grid { position: absolute; inset: 0; background-image: radial-gradient(rgba(102,126,234,.15) 1px, transparent 1px); background-size: 32px 32px; }
.hero-glow { position: absolute; border-radius: 50%; filter: blur(80px); opacity: 0.35; pointer-events: none; }
.hero-glow-1 { width: 500px; height: 500px; background: var(--primary); top: -100px; left: -100px; }
.hero-glow-2 { width: 400px; height: 400px; background: var(--secondary); bottom: -80px; right: -80px; }
.hero-container { position: relative; max-width: 1200px; margin: 0 auto; width: 100%; display: grid; grid-template-columns: 1fr 1fr; gap: 4rem; align-items: center; }
.hero-badge { display: inline-flex; align-items: center; gap: 0.5rem; background: rgba(102,126,234,.2); border: 1px solid rgba(102,126,234,.4); color: #a5b4fc; font-size: 0.8rem; font-weight: 600; padding: 0.4rem 1rem; border-radius: 20px; margin-bottom: 1.5rem; }
.badge-dot { width: 8px; height: 8px; border-radius: 50%; background: #4ade80; box-shadow: 0 0 6px #4ade80; animation: blink 1.4s ease-in-out infinite; }
@keyframes blink { 0%,100% { opacity: 1; } 50% { opacity: 0.4; } }
.hero-title { font-size: clamp(2.2rem, 4vw, 3.5rem); font-weight: 900; line-height: 1.15; color: white; margin-bottom: 1.25rem; letter-spacing: -1px; }
.gradient-text { background: linear-gradient(90deg, #818cf8, #c084fc, #f472b6); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
.hero-subtitle { font-size: 1.1rem; line-height: 1.8; color: #94a3b8; margin-bottom: 2.5rem; max-width: 480px; }
.hero-actions { display: flex; gap: 1rem; margin-bottom: 3rem; flex-wrap: wrap; }
.btn-hero-primary { padding: 0.9rem 2rem; border-radius: 12px; font-size: 1rem; font-weight: 700; cursor: pointer; background: linear-gradient(135deg, var(--primary), var(--secondary)); color: white; border: none; box-shadow: 0 8px 24px rgba(102,126,234,.4); transition: all 0.3s; }
.btn-hero-primary:hover { transform: translateY(-3px); box-shadow: 0 16px 40px rgba(102,126,234,.5); }
.btn-hero-secondary { padding: 0.9rem 2rem; border-radius: 12px; font-size: 1rem; font-weight: 600; cursor: pointer; background: rgba(255,255,255,.07); color: white; border: 1.5px solid rgba(255,255,255,.2); transition: all 0.3s; text-decoration: none; display: inline-flex; align-items: center; justify-content: center; gap: 0.4rem; }
.btn-hero-secondary:hover { background: rgba(255,255,255,.14); border-color: rgba(255,255,255,.4); }

.temp-sim-btn {
  background: rgba(245, 158, 11, 0.15) !important;
  border-color: rgba(245, 158, 11, 0.4) !important;
  color: #fcd34d !important;
}
.temp-sim-btn:hover {
  background: rgba(245, 158, 11, 0.25) !important;
  border-color: rgba(245, 158, 11, 0.6) !important;
}
.trusted-strip { display: flex; align-items: center; gap: 1rem; flex-wrap: wrap; }
.trusted-label { font-size: 0.8rem; color: #64748b; font-weight: 500; }
.trusted-logos { display: flex; gap: 0.75rem; flex-wrap: wrap; }
.trust-logo { font-size: 0.78rem; font-weight: 600; color: #94a3b8; background: rgba(255,255,255,.06); border: 1px solid rgba(255,255,255,.1); padding: 0.3rem 0.75rem; border-radius: 8px; }

/* ═══ MOCKUP ═══ */
.hero-mockup { display: flex; justify-content: center; }
.mockup-window { background: #1e293b; border: 1px solid #334155; border-radius: 14px; box-shadow: 0 40px 80px rgba(0,0,0,.6); overflow: hidden; width: 100%; max-width: 440px; }
.mockup-titlebar { display: flex; align-items: center; gap: 0.5rem; background: #0f172a; padding: 0.6rem 1rem; border-bottom: 1px solid #334155; }
.tb-dot { width: 12px; height: 12px; border-radius: 50%; }
.tb-dot.red { background: #ef4444; } .tb-dot.yellow { background: #f59e0b; } .tb-dot.green { background: #10b981; }
.tb-title { font-size: 0.72rem; color: #64748b; font-weight: 500; margin-left: 0.5rem; }
.mockup-body { padding: 1rem; }
.mini-map { position: relative; height: 200px; background: #1a2744; border-radius: 10px; overflow: hidden; margin-bottom: 1rem; }
.map-grid { position: absolute; inset: 0; background-image: linear-gradient(rgba(100,116,139,.08) 1px, transparent 1px), linear-gradient(90deg, rgba(100,116,139,.08) 1px, transparent 1px); background-size: 20px 20px; }
.map-route { position: absolute; border-top: 2px dashed rgba(102,126,234,.5); width: 60%; }
.route-1 { top: 40%; left: 10%; transform: rotate(-8deg); }
.route-2 { top: 60%; left: 30%; transform: rotate(12deg); }
.bus-pin { position: absolute; display: flex; flex-direction: column; align-items: center; gap: 2px; }
.pin-1 { top: 25%; left: 20%; } .pin-2 { top: 55%; left: 55%; } .pin-3 { top: 65%; left: 20%; }
.pin-circle { width: 28px; height: 28px; background: var(--primary); border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 14px; border: 2px solid #fff; box-shadow: 0 2px 8px rgba(0,0,0,.5); z-index: 1; animation: float 3s ease-in-out infinite; }
.pin-2 .pin-circle { background: #10b981; animation-delay: -1s; }
.pin-3 .pin-circle { background: #f59e0b; animation-delay: -2s; }
@keyframes float { 0%,100% { transform: translateY(0); } 50% { transform: translateY(-4px); } }
.pin-label { font-size: 9px; color: white; font-weight: 700; background: rgba(0,0,0,.6); padding: 1px 4px; border-radius: 4px; }
.pin-pulse { position: absolute; top: -4px; left: -4px; width: 36px; height: 36px; border-radius: 50%; background: var(--primary); opacity: 0; animation: pulse-ring 2s ease-out infinite; }
.pin-2 .pin-pulse { background: #10b981; animation-delay: -0.7s; }
.pin-3 .pin-pulse { background: #f59e0b; animation-delay: -1.4s; }
@keyframes pulse-ring { 0% { transform: scale(0.8); opacity: 0.5; } 100% { transform: scale(2.2); opacity: 0; } }
.mockup-stats { display: flex; align-items: center; justify-content: space-around; background: #0f172a; border-radius: 10px; padding: 0.75rem 1rem; }
.mstat { text-align: center; }
.mstat-num { font-size: 1.25rem; font-weight: 800; color: #f8fafc; }
.mstat-num.live { font-size: 0.8rem; font-weight: 600; color: #4ade80; }
.mstat-lbl { font-size: 0.7rem; color: #64748b; margin-top: 2px; }
.mstat-sep { width: 1px; height: 36px; background: #334155; }

/* ═══ STATS ═══ */
.stats-section { background: var(--dark-mid); border-top: 1px solid #334155; border-bottom: 1px solid #334155; }
.stats-container { max-width: 1000px; margin: 0 auto; padding: 3rem 2rem; display: flex; align-items: center; justify-content: space-around; gap: 2rem; }
.stat-item { text-align: center; }
.stat-number { display: inline-block; font-size: 3rem; font-weight: 900; color: white; line-height: 1; }
.stat-unit { display: inline-block; font-size: 1.8rem; font-weight: 700; color: var(--primary); }
.stat-label { font-size: 0.85rem; color: #94a3b8; margin-top: 0.5rem; }
.stat-divider { width: 1px; height: 60px; background: #334155; flex-shrink: 0; }

/* ═══ FEATURES ═══ */
.features-section { padding: 7rem 2rem; background: var(--light); }
.section-container { max-width: 1200px; margin: 0 auto; }
.section-header { text-align: center; margin-bottom: 4rem; }
.section-badge { display: inline-block; background: rgba(102,126,234,.1); color: var(--primary); font-size: 0.78rem; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; padding: 0.35rem 1rem; border-radius: 20px; margin-bottom: 1rem; }
.section-title { font-size: clamp(1.75rem, 3vw, 2.5rem); font-weight: 800; color: var(--dark); margin-bottom: 0.75rem; letter-spacing: -0.5px; }
.section-subtitle { font-size: 1.1rem; color: var(--gray); max-width: 520px; margin: 0 auto; }
.features-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.5rem; }
.feature-card { background: white; padding: 2rem; border-radius: var(--radius); border: 1px solid #e2e8f0; box-shadow: 0 1px 4px rgba(0,0,0,.04); transition: all 0.3s; }
.feature-card:hover { transform: translateY(-6px); box-shadow: 0 20px 40px rgba(0,0,0,.1); border-color: var(--primary); }
.feature-icon-wrap { width: 52px; height: 52px; border-radius: 14px; display: flex; align-items: center; justify-content: center; margin-bottom: 1.25rem; }
.feature-icon { font-size: 1.6rem; }
.feature-card h3 { font-size: 1.1rem; font-weight: 700; color: var(--dark); margin-bottom: 0.6rem; }
.feature-card p { font-size: 0.9rem; color: var(--gray); line-height: 1.65; margin: 0; }

/* ═══ HOW IT WORKS ═══ */
.how-section { padding: 7rem 2rem; background: white; }
.steps-track { display: flex; justify-content: center; align-items: flex-start; flex-wrap: wrap; gap: 2rem; }
.step { position: relative; display: flex; flex-direction: column; align-items: center; text-align: center; max-width: 280px; flex: 1; }
.step-connector { position: absolute; top: 32px; left: calc(50% + 48px); width: calc(100% - 24px); height: 2px; background: linear-gradient(90deg, var(--primary), var(--secondary)); pointer-events: none; }
.step-circle { width: 64px; height: 64px; border-radius: 50%; margin-bottom: 1.25rem; background: linear-gradient(135deg, var(--primary), var(--secondary)); display: flex; align-items: center; justify-content: center; box-shadow: 0 8px 24px rgba(102,126,234,.4); }
.step-num { font-size: 1.5rem; font-weight: 800; color: white; }
.step-icon { font-size: 2rem; margin-bottom: 0.75rem; }
.step-body h3 { font-size: 1.15rem; font-weight: 700; color: var(--dark); margin-bottom: 0.5rem; }
.step-body p { font-size: 0.9rem; color: var(--gray); line-height: 1.65; margin: 0; }

/* ═══ TESTIMONIALS ═══ */
.testimonials-section { padding: 7rem 2rem; background: var(--light); }
.testimonials-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.5rem; }
.testimonial-card { background: white; padding: 2rem; border-radius: var(--radius); border: 1px solid #e2e8f0; box-shadow: 0 2px 8px rgba(0,0,0,.05); transition: all 0.3s; }
.testimonial-card:hover { transform: translateY(-4px); box-shadow: 0 12px 32px rgba(0,0,0,.1); }
.stars { color: #f59e0b; font-size: 1.1rem; margin-bottom: 1rem; letter-spacing: 2px; }
.testimonial-text { font-size: 0.95rem; color: var(--dark-mid); line-height: 1.7; margin: 0 0 1.5rem 0; font-style: italic; }
.testimonial-author { display: flex; align-items: center; gap: 0.75rem; }
.author-avatar { width: 44px; height: 44px; border-radius: 50%; background: linear-gradient(135deg, var(--primary), var(--secondary)); display: flex; align-items: center; justify-content: center; font-size: 1.4rem; flex-shrink: 0; }
.author-name { font-weight: 700; font-size: 0.9rem; color: var(--dark); }
.author-role { font-size: 0.78rem; color: var(--gray); margin-top: 2px; }

/* ═══ CTA ═══ */
.cta-section { position: relative; overflow: hidden; background: var(--dark); padding: 7rem 2rem; text-align: center; color: white; }
.cta-glow { position: absolute; width: 600px; height: 600px; border-radius: 50%; background: radial-gradient(circle, rgba(102,126,234,.3), transparent 70%); top: 50%; left: 50%; transform: translate(-50%, -50%); pointer-events: none; }
.cta-content { position: relative; }
.cta-badge { display: inline-block; background: rgba(102,126,234,.2); border: 1px solid rgba(102,126,234,.4); color: #a5b4fc; font-size: 0.8rem; font-weight: 700; padding: 0.35rem 1rem; border-radius: 20px; margin-bottom: 1.5rem; }
.cta-content h2 { font-size: clamp(2rem, 4vw, 3rem); font-weight: 900; margin-bottom: 1rem; letter-spacing: -0.5px; }
.cta-content > p { font-size: 1.1rem; color: #94a3b8; margin-bottom: 2.5rem; }
.cta-actions { display: flex; gap: 1rem; justify-content: center; flex-wrap: wrap; margin-bottom: 1.5rem; }
.btn-cta-primary { padding: 1rem 2.5rem; border-radius: 12px; font-size: 1.05rem; font-weight: 700; cursor: pointer; border: none; background: linear-gradient(135deg, var(--primary), var(--secondary)); color: white; box-shadow: 0 8px 24px rgba(102,126,234,.4); transition: all 0.3s; }
.btn-cta-primary:hover { transform: translateY(-3px); box-shadow: 0 16px 40px rgba(102,126,234,.5); }
.btn-cta-secondary { padding: 1rem 2.5rem; border-radius: 12px; font-size: 1.05rem; font-weight: 600; cursor: pointer; background: rgba(255,255,255,.06); color: white; border: 1.5px solid rgba(255,255,255,.2); transition: all 0.3s; }
.btn-cta-secondary:hover { background: rgba(255,255,255,.14); }
.cta-note { font-size: 0.85rem; color: #64748b; margin: 0; }

/* ═══ FOOTER ═══ */
.landing-footer { background: #020617; color: white; padding: 4rem 2rem 2rem; }
.footer-container { max-width: 1200px; margin: 0 auto; display: grid; grid-template-columns: 2fr 3fr; gap: 4rem; margin-bottom: 3rem; }
.footer-logo { font-size: 1.25rem; font-weight: 800; margin-bottom: 0.75rem; }
.footer-brand p { color: #64748b; font-size: 0.9rem; line-height: 1.6; margin-bottom: 1.25rem; }
.footer-badges { display: flex; gap: 0.5rem; flex-wrap: wrap; }
.fbadge { font-size: 0.75rem; font-weight: 600; color: #94a3b8; background: rgba(255,255,255,.05); border: 1px solid #334155; padding: 0.3rem 0.75rem; border-radius: 8px; }
.footer-links { display: grid; grid-template-columns: repeat(3,1fr); gap: 2rem; }
.footer-col h4 { font-size: 0.85rem; font-weight: 700; color: white; margin-bottom: 1.25rem; text-transform: uppercase; letter-spacing: 0.5px; }
.footer-col a, .footer-col button { display: block; color: #64748b; text-decoration: none; font-size: 0.875rem; margin-bottom: 0.75rem; transition: color 0.2s; background: none; border: none; cursor: pointer; padding: 0; font-family: inherit; text-align: left; }
.footer-col a:hover, .footer-col button:hover { color: var(--primary); }
.footer-bottom { max-width: 1200px; margin: 0 auto; padding-top: 2rem; border-top: 1px solid #1e293b; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem; }
.footer-bottom p { color: #475569; font-size: 0.85rem; margin: 0; }
.footer-bottom-links { display: flex; gap: 1.5rem; }
.footer-bottom-links a { color: #475569; text-decoration: none; font-size: 0.85rem; transition: color 0.2s; }
.footer-bottom-links a:hover { color: var(--primary); }

/* ═══ MOBILE MENU ═══ */
.mobile-menu-btn { display: none; background: none; border: none; font-size: 1.8rem; color: var(--dark); cursor: pointer; padding: 0; }
.mobile-menu-overlay { position: fixed; inset: 0; background: rgba(255,255,255,0.98); z-index: 2000; display: flex; align-items: center; justify-content: center; opacity: 0; pointer-events: none; transition: opacity 0.3s ease; backdrop-filter: blur(10px); }
.mobile-menu-overlay.open { opacity: 1; pointer-events: auto; }
.mobile-close-btn { position: absolute; top: 1.5rem; right: 1.5rem; background: none; border: none; font-size: 2rem; color: var(--dark); cursor: pointer; }
.mobile-nav-links { display: flex; flex-direction: column; gap: 2rem; align-items: center; }
.mobile-nav-links button { background: none; border: none; font-size: 1.5rem; font-weight: 700; color: var(--dark); cursor: pointer; transition: color 0.2s; }
.mobile-nav-links button:hover { color: var(--primary); }
.mobile-auth-links { margin-top: 1rem; display: flex; flex-direction: column; gap: 1rem; width: 100%; padding: 0 2rem; }
.mobile-auth-links button { width: 100%; padding: 1rem; font-size: 1.1rem; text-align: center; }

/* ═══ CONTACT ═══ */
.contact-section { padding: 7rem 2rem; background: white; }
.contact-grid { display: grid; grid-template-columns: 1fr 1.2fr; gap: 4rem; margin-top: 3rem; }
.contact-info { display: flex; flex-direction: column; gap: 1.5rem; }
.contact-card { display: flex; align-items: center; gap: 1.5rem; padding: 1.5rem; background: var(--light); border-radius: 12px; border: 1px solid #e2e8f0; transition: all 0.3s; }
.contact-card:hover { transform: translateX(10px); border-color: var(--primary); }
.contact-icon { font-size: 2rem; }
.contact-details h4 { margin: 0 0 4px 0; color: var(--dark); font-size: 1rem; }
.contact-details p { margin: 0; color: var(--gray); font-size: 0.9rem; }

.contact-form-wrap { background: var(--white); padding: 2.5rem; border-radius: var(--radius); border: 1px solid #e2e8f0; box-shadow: 0 20px 40px rgba(0,0,0,.05); }
.landing-form { display: flex; flex-direction: column; gap: 1.25rem; }
.landing-form input, .landing-form textarea { width: 100%; padding: 1rem; border: 1.5px solid #e2e8f0; border-radius: 10px; font-family: inherit; font-size: 0.95rem; transition: border-color 0.2s; }
.landing-form input:focus, .landing-form textarea:focus { outline: none; border-color: var(--primary); }

/* ═══ RESPONSIVE ═══ */
@media (max-width: 1024px) {
  .nav-menu, .header-actions { display: none; }
  .mobile-menu-btn { display: block; }
  .hero-container { grid-template-columns: 1fr; gap: 3rem; }
  .hero-mockup { display: none; }
  .step-connector { display: none; }
  .footer-container { grid-template-columns: 1fr; gap: 2rem; }
  .contact-grid { grid-template-columns: 1fr; gap: 3rem; }
}
@media (max-width: 768px) {
  .header-container { padding: 0 1.5rem; gap: 1rem; }
  .stats-container { flex-wrap: wrap; gap: 2rem; }
  .stat-divider { display: none; }
  .hero-section { padding: 4rem 1.5rem 3rem; min-height: auto; margin-top: 70px; }
  .features-section, .how-section, .testimonials-section, .cta-section, .contact-section { padding: 4rem 1.5rem; }
  .footer-links { grid-template-columns: 1fr 1fr; }
  .footer-bottom { flex-direction: column; text-align: center; }
  .section-title { white-space: normal; line-height: 1.3; }
}
@media (max-width: 480px) {
  .header-container { padding: 0 1rem; gap: 0.5rem; }
  .logo-text { font-size: 1.1rem; }
  .header-actions { gap: 0.4rem; }
  .btn-ghost, .btn-accent { padding: 0.4rem 0.6rem; font-size: 0.75rem; border-radius: 8px; }
  .hero-title { font-size: 2rem; }
  .hero-actions { flex-direction: column; width: 100%; }
  .btn-hero-primary, .btn-hero-secondary { width: 100%; text-align: center; }
  .footer-links { grid-template-columns: 1fr; }
}
</style>