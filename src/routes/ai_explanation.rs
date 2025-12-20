use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct SignalExplanation {
    pub symbol: String,
    pub current_signal: String,
    pub explanation: String,
    pub confidence: f64,
    pub emoji: String,
    pub vibe: String,
    pub simple_advice: String,
    pub risk_level: String,
}

pub struct AIExplainer {
    api_key: String,
}

impl AIExplainer {
    pub fn new() -> Self {
        Self {
            api_key: std::env::var("OPENAI_API_KEY").unwrap_or_default(),
        }
    }

    pub async fn explain_signal(
        &self,
        symbol: &str,
        signal: &str,
        price: f64,
        change_24h: f64,
    ) -> SignalExplanation {
        let (explanation, emoji, vibe, risk_level) = match signal {
            "strong_buy" | "buy" | "weak_buy" => (
                format!("{} is showing bullish momentum at ${:.2}. 24h change: {:.2}%", symbol, price, change_24h),
                "🚀",
                "Bullish vibes",
                "Medium"
            ),
            "strong_sell" | "sell" | "weak_sell" => (
                format!("{} might be overbought at ${:.2}. 24h change: {:.2}%", symbol, price, change_24h),
                "📉",
                "Caution vibes",
                "High"
            ),
            "hold" => (
                format!("{} is in consolidation phase at ${:.2}. 24h change: {:.2}%", symbol, price, change_24h),
                "⚖️",
                "Neutral vibes",
                "Low"
            ),
            _ => (
                format!("{} at ${:.2}: Market sentiment is mixed. 24h change: {:.2}%", symbol, price, change_24h),
                "🤔",
                "Mixed vibes",
                "Medium"
            ),
        };

        let simple_advice = if change_24h > 10.0 {
            "🚨 Very strong trend - High risk opportunity"
        } else if change_24h > 5.0 {
            "🔥 Strong trend - Consider position sizing"
        } else if change_24h < -10.0 {
            "💥 Sharp decline - Possible buying opportunity"
        } else if change_24h < -5.0 {
            "⚠️ High volatility - Risk management crucial"
        } else {
            "📊 Stable range - Good for swing trading"
        };

        SignalExplanation {
            symbol: symbol.to_string(),
            current_signal: signal.to_string(),
            explanation,
            confidence: 0.85,
            emoji: emoji.to_string(),
            vibe: vibe.to_string(),
            simple_advice: simple_advice.to_string(),
            risk_level: risk_level.to_string(),
        }
    }
}
