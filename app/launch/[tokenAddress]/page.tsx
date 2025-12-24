"use client";

import { useState, useEffect, useMemo } from "react";
import { ethers } from "ethers";
import { useAccount, useWalletClient } from "wagmi";
import { motion, AnimatePresence } from "framer-motion";
import { FaFire, FaRocket, FaInfoCircle } from "react-icons/fa";
import curveABI from "@/app/lib/curveABI.json";
import { CONTRACTS } from "@/app/lib/contractAddresses";

export default function TokenTradePage({ params }: { params: { tokenAddress: string } }) {
  const { address } = useAccount();
  const { data: walletClient } = useWalletClient();
  
  const [mode, setMode] = useState<"buy" | "sell">("buy");
  const [amount, setAmount] = useState("");
  const [progress, setProgress] = useState(0); // Progress towards graduation (0-10000 bps)
  const [tokenStats, setTokenStats] = useState({ symbol: "...", name: "...", price: "0" });
  const [loading, setLoading] = useState(false);

  const curveAddress = "0x..."; // Logic to fetch curve address from factory using params.tokenAddress

  // --- Real-time Stats Fetching ---
  const fetchStats = async () => {
    try {
      const provider = new ethers.JsonRpcProvider("http://devnet-rpc.mocachain.org");
      const curve = new ethers.Contract(curveAddress, curveABI, provider);
      
      const [bps, price, initial] = await Promise.all([
        curve.getProgressBps(),
        curve.currentPrice(),
        curve.initialTokens()
      ]);
      
      setProgress(Number(bps));
      setTokenStats(prev => ({ ...prev, price: ethers.formatEther(price) }));
    } catch (e) { console.error("Stats fail", e); }
  };

  useEffect(() => {
    const interval = setInterval(fetchStats, 5000);
    return () => clearInterval(interval);
  }, [curveAddress]);

  const handleTrade = async () => {
    if (!walletClient) return;
    setLoading(true);
    try {
      const signer = await (new ethers.BrowserProvider(walletClient.transport)).getSigner();
      const curve = new ethers.Contract(curveAddress, curveABI, signer);
      
      if (mode === "buy") {
        const tx = await curve.buy(0, { value: ethers.parseEther(amount) });
        await tx.wait();
      } else {
        const tx = await curve.sell(ethers.parseEther(amount), 0);
        await tx.wait();
      }
      fetchStats();
    } catch (e) { console.error(e); } finally { setLoading(false); }
  };

  return (
    <div className="max-w-6xl mx-auto px-4 py-12 grid grid-cols-1 lg:grid-cols-3 gap-8">
      
      {/* Left: Token Analytics */}
      <div className="lg:col-span-2 space-y-6">
        <div className="bg-[#111] border border-gray-800 p-8 rounded-[32px]">
          <div className="flex justify-between items-start mb-6">
            <div>
              <h1 className="text-4xl font-black mb-2 flex items-center gap-3">
                {tokenStats.name} <span className="text-gray-600 text-xl">${tokenStats.symbol}</span>
              </h1>
              <p className="text-blue-500 font-mono text-sm">{params.tokenAddress}</p>
            </div>
            <div className="text-right">
              <span className="text-gray-500 text-xs uppercase font-bold">Price</span>
              <div className="text-2xl font-mono text-green-400">{tokenStats.price} MOCA</div>
            </div>
          </div>

          {/* Bonding Curve Progress Bar */}
          <div className="mt-10">
            <div className="flex justify-between items-end mb-2">
              <span className="text-sm font-bold flex items-center gap-2">
                <FaRocket className="text-orange-500" /> Bonding Curve Progress
              </span>
              <span className="font-mono text-orange-500">{(progress / 100).toFixed(2)}%</span>
            </div>
            <div className="h-4 w-full bg-gray-900 rounded-full overflow-hidden border border-gray-800">
              <motion.div 
                initial={{ width: 0 }}
                animate={{ width: `${progress / 100}%` }}
                className="h-full bg-gradient-to-r from-orange-600 to-yellow-400 shadow-[0_0_20px_rgba(249,115,22,0.4)]"
              />
            </div>
            <p className="text-gray-500 text-xs mt-4 leading-relaxed">
              When the curve hits 100%, liquidity graduates to the DEX and is locked forever. 
              Current progress is based on the circulating supply sold.
            </p>
          </div>
        </div>

        {/* Placeholder for a Chart (Recruiters love seeing Recharts here) */}
        <div className="h-64 bg-[#0a0a0a] border border-dashed border-gray-800 rounded-[32px] flex items-center justify-center text-gray-700">
          Trading Chart Integration (Recharts / TradingView)
        </div>
      </div>

      {/* Right: Trading Terminal */}
      <div className="space-y-4">
        <div className="bg-[#111] border border-gray-800 p-6 rounded-[32px] sticky top-24">
          <div className="flex bg-gray-900 p-1 rounded-2xl mb-6">
            <button 
              onClick={() => setMode("buy")}
              className={`flex-1 py-2 rounded-xl text-sm font-bold transition-all ${mode === "buy" ? "bg-green-500 text-black" : "text-gray-500"}`}
            >Buy</button>
            <button 
              onClick={() => setMode("sell")}
              className={`flex-1 py-2 rounded-xl text-sm font-bold transition-all ${mode === "sell" ? "bg-red-500 text-white" : "text-gray-500"}`}
            >Sell</button>
          </div>

          <div className="bg-[#1a1a1a] p-4 rounded-2xl border border-gray-800 focus-within:border-gray-600 mb-6">
            <div className="flex justify-between text-xs text-gray-500 mb-2 font-bold uppercase">
              <span>Amount</span>
              <span>{mode === "buy" ? "MOCA" : "Tokens"}</span>
            </div>
            <input 
              type="number" 
              value={amount} 
              onChange={e => setAmount(e.target.value)}
              className="bg-transparent text-2xl w-full outline-none font-mono" 
              placeholder="0.0"
            />
          </div>

          <button 
            disabled={loading || !amount}
            onClick={handleTrade}
            className={`w-full py-4 rounded-2xl font-black text-lg transition-all shadow-xl ${
              mode === "buy" 
              ? "bg-green-500 text-black hover:bg-green-400 shadow-green-500/10" 
              : "bg-red-500 text-white hover:bg-red-400 shadow-red-500/10"
            }`}
          >
            {loading ? "Transacting..." : mode === "buy" ? "Place Buy Order" : "Place Sell Order"}
          </button>
          
          <div className="mt-6 p-4 bg-blue-500/5 border border-blue-500/20 rounded-2xl flex gap-3">
            <FaInfoCircle className="text-blue-500 shrink-0 mt-1" />
            <p className="text-[10px] text-blue-300 leading-tight italic">
              Fair Launch Guarantee: No team allocation. No pre-sale. Fully autonomous mathematical price discovery.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}