export default function ContactPage() {
  return (
    <div
      className="min-h-screen flex flex-col items-center px-4 py-8"
      style={{
        background: 'linear-gradient(180deg, #87CEEB 0%, #82c45d 40%, #f4d03f 70%, #8B5E3C 100%)',
      }}
    >
      <div className="card-panel w-full max-w-sm">
        <div className="text-center mb-5">
          <div className="text-4xl">📧</div>
          <h1 className="font-pixel text-2xl font-bold text-meadow-dark mt-2">CONTACT</h1>
          <p className="font-pixel text-base text-meadow-earth mt-1">Get in touch!</p>
        </div>

        <div className="flex flex-col gap-3">
          <a
            href="https://facebook.com/YOUR_PROFILE"
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary text-center"
            style={{ background: 'linear-gradient(180deg, #4267B2, #365899)', boxShadow: '0 4px 0 #29487d' }}
          >
            📘 Facebook
          </a>
          <a
            href="mailto:hello@nexusarcade.com"
            className="btn-primary text-center"
          >
            ✉️ hello@nexusarcade.com
          </a>
        </div>
      </div>
    </div>
  )
}
