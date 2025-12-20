#!/bin/bash

# Backup original file
cp src/routes/signals.rs src/routes/signals.rs.backup

# Remove the #[get] macros from AI functions and make them regular async functions
sed -i '395s/^#[get("\/explain-signal")]/\/\/ #[get("\/explain-signal")]/' src/routes/signals.rs
sed -i '439s/^#[get("\/explain-all-signals")]/\/\/ #[get("\/explain-all-signals")]/' src/routes/signals.rs

# Or simpler: Use this updated version
cat > src/routes/signals.rs << 'SIGNALS_EOF'
use actix_web::{get, HttpResponse, Responder, web};
use serde::{Deserialize, Serialize};
use chrono::Utc;
use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use std::time::{SystemTime, Duration};

// Import AI module
use super::ai_explanation::{AIExplainer, SignalExplanation};

// Store to keep alerts in memory
static ALERTS: std::sync::OnceLock<Arc<Mutex<Vec<TradingViewAlert>>>> = std::sync::OnceLock::new();
static PRICE_CACHE: std::sync::OnceLock<Arc<Mutex<HashMap<String, (PriceData, SystemTime)>>>> = std::sync::OnceLock::new();

#[derive(Debug, Serialize, Clone, Deserialize)]
pub struct PriceData {
    pub symbol: String,
    pub price: f64,
    pub timestamp: i64,
    pub change_24h: f64,
    pub market_cap: Option<f64>,
    pub volume_24h: Option<f64>,
}

#[derive(Debug, Serialize, Clone, Deserialize)]
pub struct TradingViewAlert {
    pub symbol: String,
    pub price: f64,
    pub alert_name: String,
    pub timestamp: i64,
}

#[derive(Debug, Deserialize)]
pub struct TradingViewWebhook {
    pub symbol: String,
    pub price: f64,
    pub alert_name: Option<String>,
}

// ========== HEALTH CHECK ==========
#[get("/health")]
pub async fn health_check() -> impl Responder {
    HttpResponse::Ok().json(json!({
        "status": "healthy",
        "service": "trading-signals-backend",
        "timestamp": Utc::now().timestamp(),
        "version": "1.0.0",
        "supported_coins": ["BTC", "ETH", "SOL", "PAXG"],
        "endpoints": [
            "/health",
            "/prices", 
            "/signals",
            "/explain-signal",
            "/explain-all-signals",
            "/tradingview-webhook",
            "/tradingview-alerts",
            "/alerts/{symbol}"
        ]
    }))
}

// ========== REAL PRICE FETCHING ==========
fn get_coingecko_id(symbol: &str) -> Option<&'static str> {
    match symbol.to_uppercase().as_str() {
        "BTC" => Some("bitcoin"),
        "ETH" => Some("ethereum"),
        "SOL" => Some("solana"),
        "PAXG" => Some("pax-gold"),
        _ => None,
    }
}

async fn fetch_live_price(symbol: &str) -> Result<PriceData, String> {
    let symbol_upper = symbol.to_uppercase();
    
    // Check cache
    if let Some(cache) = PRICE_CACHE.get() {
        let cache_lock = cache.lock().unwrap();
        if let Some((data, timestamp)) = cache_lock.get(&symbol_upper) {
            if SystemTime::now().duration_since(*timestamp)
                .unwrap_or(Duration::from_secs(0))
                .as_secs() < 30 {
                return Ok(data.clone());
            }
        }
    }
    
    let coin_id = get_coingecko_id(&symbol_upper)
        .ok_or_else(|| format!("Unknown symbol: {}", symbol))?;
    
    let url = format!("https://api.coingecko.com/api/v3/simple/price?ids={}&vs_currencies=usd&include_24hr_change=true&include_market_cap=true&include_24hr_vol=true", 
        coin_id);
    
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(10))
        .build()
        .map_err(|e| format!("Client error: {}", e))?;
    
    let response = client.get(&url)
        .header("User-Agent", "TradingSignalsBot/1.0")
        .send()
        .await
        .map_err(|e| format!("Network error: {}", e))?;
    
    if !response.status().is_success() {
        return Err(format!("API error: {}", response.status()));
    }
    
    let data: serde_json::Value = response.json()
        .await
        .map_err(|e| format!("JSON error: {}", e))?;
    
    let coin_data = data.get(coin_id)
        .ok_or_else(|| format!("No data for {}", symbol))?;
    
    let price = coin_data.get("usd")
        .and_then(|v| v.as_f64())
        .ok_or("No price in response")?;
    
    let change_24h = coin_data.get("usd_24h_change")
        .and_then(|v| v.as_f64())
        .unwrap_or(0.0);
    
    let market_cap = coin_data.get("usd_market_cap")
        .and_then(|v| v.as_f64());
    
    let volume_24h = coin_data.get("usd_24h_vol")
        .and_then(|v| v.as_f64());
    
    let price_data = PriceData {
        symbol: symbol_upper.clone(),
        price,
        timestamp: Utc::now().timestamp(),
        change_24h,
        market_cap,
        volume_24h,
    };
    
    // Update cache
    if let Some(cache) = PRICE_CACHE.get() {
        let mut cache_lock = cache.lock().unwrap();
        cache_lock.insert(symbol_upper, (price_data.clone(), SystemTime::now()));
    } else {
        let mut new_cache = HashMap::new();
        new_cache.insert(symbol_upper, (price_data.clone(), SystemTime::now()));
        let _ = PRICE_CACHE.set(Arc::new(Mutex::new(new_cache)));
    }
    
    Ok(price_data)
}

#[get("/prices")]
pub async fn get_prices() -> impl Responder {
    println!("🚀 Fetching live prices from CoinGecko...");
    
    let symbols = vec!["BTC", "ETH", "SOL", "PAXG"];
    let mut prices = Vec::new();
    
    for symbol in symbols {
        match fetch_live_price(symbol).await {
            Ok(price_data) => {
                println!("✅ {}: ${:.2} ({:.2}%)", symbol, price_data.price, price_data.change_24h);
                prices.push(price_data);
            },
            Err(e) => {
                println!("❌ Failed {}: {}", symbol, e);
                prices.push(PriceData {
                    symbol: symbol.to_string(),
                    price: 0.0,
                    timestamp: Utc::now().timestamp(),
                    change_24h: 0.0,
                    market_cap: None,
                    volume_24h: None,
                });
            }
        }
        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
    }
    
    HttpResponse::Ok().json(json!({
        "prices": prices,
        "count": prices.len(),
        "timestamp": Utc::now().timestamp(),
        "source": "CoinGecko API"
    }))
}

// ========== SIGNAL GENERATION ==========
#[get("/signals")]
pub async fn get_signals() -> impl Responder {
    println!("📈 Generating trading signals...");
    
    let symbols = vec!["BTC", "ETH", "SOL", "PAXG"];
    let mut signals = Vec::new();
    
    for symbol in symbols {
        match fetch_live_price(symbol).await {
            Ok(price_data) => {
                let (signal, confidence) = generate_signal(&price_data);
                
                signals.push(json!({
                    "symbol": symbol,
                    "price": price_data.price,
                    "change_24h": price_data.change_24h,
                    "signal": signal,
                    "confidence": (confidence * 100.0).round() / 100.0,
                    "action": get_action_from_signal(&signal),
                    "timestamp": Utc::now().timestamp(),
                }));
            },
            Err(e) => {
                signals.push(json!({
                    "symbol": symbol,
                    "error": e,
                    "signal": "error",
                    "confidence": 0.0,
                    "timestamp": Utc::now().timestamp(),
                }));
            }
        }
    }
    
    HttpResponse::Ok().json(json!({
        "signals": signals,
        "count": signals.len(),
        "timestamp": Utc::now().timestamp(),
    }))
}

fn generate_signal(price_data: &PriceData) -> (String, f64) {
    match price_data.change_24h {
        c if c > 10.0 => ("strong_sell".to_string(), 0.85),
        c if c > 5.0 => ("sell".to_string(), 0.75),
        c if c > 2.0 => ("weak_sell".to_string(), 0.65),
        c if c < -10.0 => ("strong_buy".to_string(), 0.85),
        c if c < -5.0 => ("buy".to_string(), 0.75),
        c if c < -2.0 => ("weak_buy".to_string(), 0.65),
        _ => ("hold".to_string(), 0.8),
    }
}

fn get_action_from_signal(signal: &str) -> &'static str {
    match signal {
        "strong_buy" => "ENTER_LONG_NOW",
        "buy" => "ENTER_LONG",
        "strong_sell" => "ENTER_SHORT_NOW",
        "sell" => "ENTER_SHORT",
        _ => "HOLD_POSITION"
    }
}

// ========== TRADINGVIEW WEBHOOK ==========
pub async fn tradingview_webhook(data: web::Json<TradingViewWebhook>) -> impl Responder {
    println!("📈 TradingView webhook received!");
    
    let symbol = clean_symbol(&data.symbol);
    let valid_symbols = ["BTC", "ETH", "SOL", "PAXG"];
    
    if !valid_symbols.contains(&symbol.as_str()) {
        return HttpResponse::BadRequest().json(json!({
            "status": "error",
            "message": format!("Unsupported symbol: {}. Only BTC, ETH, SOL, PAXG.", symbol),
        }));
    }
    
    let alert = TradingViewAlert {
        symbol: symbol.clone(),
        price: data.price,
        alert_name: data.alert_name.clone().unwrap_or_else(|| "Unknown".to_string()),
        timestamp: Utc::now().timestamp(),
    };
    
    let alerts_store = ALERTS.get_or_init(|| Arc::new(Mutex::new(Vec::new())));
    let mut alerts = alerts_store.lock().unwrap();
    alerts.push(alert.clone());
    
    // FIXED: Store length in variable before using it
    let alerts_len = alerts.len();
    if alerts_len > 50 {
        alerts.drain(0..alerts_len - 50);
    }
    
    HttpResponse::Ok().json(json!({
        "status": "success",
        "alert": alert,
        "timestamp": Utc::now().timestamp()
    }))
}

fn clean_symbol(raw_symbol: &str) -> String {
    let cleaned = if raw_symbol.contains(":") {
        raw_symbol.split(':').last().unwrap_or(raw_symbol)
            .replace("USDT", "")
            .replace("USD", "")
    } else {
        raw_symbol.to_string()
    };
    
    cleaned.chars()
        .filter(|c| c.is_alphabetic())
        .collect::<String>()
        .to_uppercase()
}

// ========== ALERTS ENDPOINTS ==========
#[get("/tradingview-alerts")]
pub async fn get_tradingview_alerts() -> impl Responder {
    let alerts = ALERTS.get()
        .map(|store| store.lock().unwrap().clone())
        .unwrap_or_else(Vec::new);
    
    HttpResponse::Ok().json(json!({
        "alerts": alerts,
        "count": alerts.len(),
        "timestamp": Utc::now().timestamp()
    }))
}

#[get("/alerts/{symbol}")]
pub async fn get_symbol_alerts(symbol: web::Path<String>) -> impl Responder {
    let symbol_str = symbol.into_inner().to_uppercase();
    
    let alerts = ALERTS.get()
        .map(|store| {
            let store_lock = store.lock().unwrap();
            store_lock.iter()
                .filter(|a| a.symbol == symbol_str)
                .cloned()
                .collect::<Vec<_>>()
        })
        .unwrap_or_else(Vec::new);
    
    HttpResponse::Ok().json(json!({
        "symbol": symbol_str,
        "alerts": alerts,
        "count": alerts.len(),
        "timestamp": Utc::now().timestamp()
    }))
}

// ========== UTILITY ENDPOINTS ==========
pub async fn clear_alerts() -> impl Responder {
    if let Some(alerts_store) = ALERTS.get() {
        let mut alerts = alerts_store.lock().unwrap();
        alerts.clear();
    }
    
    HttpResponse::Ok().json(json!({
        "status": "success",
        "message": "All alerts cleared",
        "timestamp": Utc::now().timestamp()
    }))
}

pub async fn clear_cache() -> impl Responder {
    if let Some(cache) = PRICE_CACHE.get() {
        let mut cache_lock = cache.lock().unwrap();
        cache_lock.clear();
    }
    
    HttpResponse::Ok().json(json!({
        "status": "success",
        "message": "Price cache cleared",
        "timestamp": Utc::now().timestamp()
    }))
}

// ========== CACHE STATS ==========
#[get("/cache-stats")]
pub async fn get_cache_stats() -> impl Responder {
    let cache_info = if let Some(cache) = PRICE_CACHE.get() {
        let cache_lock = cache.lock().unwrap();
        json!({
            "entries": cache_lock.len(),
            "symbols": cache_lock.keys().cloned().collect::<Vec<_>>()
        })
    } else {
        json!({"entries": 0, "symbols": []})
    };
    
    let alerts_info = if let Some(alerts_store) = ALERTS.get() {
        let alerts = alerts_store.lock().unwrap();
        json!({
            "total_alerts": alerts.len()
        })
    } else {
        json!({"total_alerts": 0})
    };
    
    HttpResponse::Ok().json(json!({
        "price_cache": cache_info,
        "alerts_store": alerts_info,
        "timestamp": Utc::now().timestamp(),
        "supported_coins": ["BTC", "ETH", "SOL", "PAXG"]
    }))
}

// ========== AI EXPLANATION ENDPOINTS ==========
#[derive(Deserialize)]
pub struct ExplainQuery {
    pub symbol: Option<String>,
}

// Regular async function (NOT #[get] macro)
pub async fn explain_signal(query: web::Query<ExplainQuery>) -> impl Responder {
    let explainer = AIExplainer::new();
    
    // Get symbol from query or default to BTC
    let requested_symbol = query.symbol.clone().unwrap_or_else(|| "BTC".to_string());
    let symbol_upper = requested_symbol.to_uppercase();
    
    // Validate symbol
    let valid_symbols = ["BTC", "ETH", "SOL", "PAXG"];
    if !valid_symbols.contains(&symbol_upper.as_str()) {
        return HttpResponse::BadRequest().json(json!({
            "error": "Unsupported symbol",
            "message": format!("Only {} are supported", valid_symbols.join(", ")),
            "symbol": symbol_upper
        }));
    }
    
    // Get live price data
    match fetch_live_price(&symbol_upper).await {
        Ok(price_data) => {
            // Generate signal from price data
            let (signal, _) = generate_signal(&price_data);
            
            // Create AI explanation
            let explanation = explainer.explain_signal(
                &symbol_upper,
                &signal,
                price_data.price,
                price_data.change_24h,
            ).await;
            
            HttpResponse::Ok().json(explanation)
        },
        Err(e) => {
            HttpResponse::ServiceUnavailable().json(json!({
                "error": "Failed to fetch data",
                "message": e,
                "symbol": symbol_upper
            }))
        }
    }
}

// Regular async function (NOT #[get] macro)
pub async fn explain_all_signals() -> impl Responder {
    let explainer = AIExplainer::new();
    let symbols = vec!["BTC", "ETH", "SOL", "PAXG"];
    let mut explanations = Vec::new();
    
    for symbol in symbols {
        match fetch_live_price(symbol).await {
            Ok(price_data) => {
                let (signal, _) = generate_signal(&price_data);
                
                let explanation = explainer.explain_signal(
                    symbol,
                    &signal,
                    price_data.price,
                    price_data.change_24h,
                ).await;
                
                explanations.push(explanation);
            },
            Err(e) => {
                // Add error explanation
                explanations.push(SignalExplanation {
                    symbol: symbol.to_string(),
                    current_signal: "error".to_string(),
                    explanation: format!("Failed to fetch data: {}", e),
                    confidence: 0.0,
                    emoji: "❌".to_string(),
                    vibe: "Error vibes".to_string(),
                    simple_advice: "Data unavailable".to_string(),
                    risk_level: "Unknown".to_string(),
                });
            }
        }
        // Small delay to avoid rate limiting
        tokio::time::sleep(tokio::time::Duration::from_millis(50)).await;
    }
    
    HttpResponse::Ok().json(json!({
        "explanations": explanations,
        "count": explanations.len(),
        "timestamp": Utc::now().timestamp()
    }))
}
SIGNALS_EOF
