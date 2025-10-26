export default function Home() {
  return (
    <main className="min-h-screen bg-gradient-to-br from-blue-900 via-purple-900 to-black">
      <div className="container mx-auto px-4 py-16">
        <header className="text-center mb-16">
          <h1 className="text-6xl font-bold text-white mb-4">
            Future Flux
          </h1>
          <p className="text-2xl text-blue-200">
            Decentralized Exchange for Real World Assets
          </p>
        </header>

        <div className="grid md:grid-cols-3 gap-8 max-w-6xl mx-auto">
          <FeatureCard
            title="Trade RWA"
            description="Exchange tokenized real-world assets securely on-chain"
            icon="💱"
          />
          <FeatureCard
            title="Provide Liquidity"
            description="Earn fees by providing liquidity to trading pairs"
            icon="💧"
          />
          <FeatureCard
            title="Secure & Transparent"
            description="Built on blockchain with full transparency and security"
            icon="🔒"
          />
        </div>

        <div className="mt-16 text-center">
          <button className="bg-blue-600 hover:bg-blue-700 text-white font-bold py-4 px-8 rounded-lg text-xl transition-colors">
            Connect Wallet
          </button>
        </div>

        <div className="mt-24 bg-white/10 rounded-lg p-8 max-w-4xl mx-auto">
          <h2 className="text-3xl font-bold text-white mb-6">
            About Future Flux
          </h2>
          <p className="text-gray-200 leading-relaxed">
            Future Flux is a cutting-edge decentralized exchange platform designed specifically
            for trading Real World Assets (RWA). Our platform bridges traditional finance with
            DeFi, enabling seamless trading of tokenized assets like real estate, commodities,
            and other tangible assets on the blockchain.
          </p>
        </div>
      </div>
    </main>
  )
}

function FeatureCard({ title, description, icon }: { title: string; description: string; icon: string }) {
  return (
    <div className="bg-white/10 backdrop-blur-lg rounded-lg p-6 hover:bg-white/20 transition-colors">
      <div className="text-5xl mb-4">{icon}</div>
      <h3 className="text-xl font-bold text-white mb-2">{title}</h3>
      <p className="text-gray-300">{description}</p>
    </div>
  )
}
