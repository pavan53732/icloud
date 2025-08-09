const fs = require('fs');
const path = require('path');

/**
 * Event Logger - Off-chain shadow logging for forensics defense
 * Maintains alternative event logs for post-hoc proof
 */

class EventLogger {
    constructor(config = {}) {
        this.logDir = config.logDir || path.join(__dirname, '..', 'logs');
        this.maxLogSize = config.maxLogSize || 100 * 1024 * 1024; // 100MB
        this.rotationCount = config.rotationCount || 10;
        
        // Ensure log directory exists
        if (!fs.existsSync(this.logDir)) {
            fs.mkdirSync(this.logDir, { recursive: true });
        }
        
        this.currentLogFile = this.getLogFileName();
        this.eventCount = 0;
    }
    
    /**
     * Log transfer event with full context
     */
    logTransfer(from, to, amount, txHash, metadata = {}) {
        const event = {
            type: 'Transfer',
            timestamp: Date.now(),
            blockNumber: metadata.blockNumber || 0,
            from: from,
            to: to,
            amount: amount,
            txHash: txHash,
            realUSDT: metadata.realUSDT || false,
            spoofed: metadata.spoofed || false,
            ghostEmitted: metadata.ghostEmitted || false,
            quantumState: metadata.quantumState || null,
            observerEffect: metadata.observerEffect || null
        };
        
        this.writeEvent(event);
    }
    
    /**
     * Log approval event
     */
    logApproval(owner, spender, amount, txHash, metadata = {}) {
        const event = {
            type: 'Approval',
            timestamp: Date.now(),
            blockNumber: metadata.blockNumber || 0,
            owner: owner,
            spender: spender,
            amount: amount,
            txHash: txHash,
            spoofed: metadata.spoofed || false
        };
        
        this.writeEvent(event);
    }
    
    /**
     * Log suspicious activity
     */
    logSuspiciousActivity(address, activity, score, action) {
        const event = {
            type: 'SuspiciousActivity',
            timestamp: Date.now(),
            address: address,
            activity: activity,
            suspicionScore: score,
            actionTaken: action,
            metadata: {
                userAgent: activity.userAgent || 'unknown',
                queryCount: activity.queryCount || 0,
                pattern: activity.pattern || 'none'
            }
        };
        
        this.writeEvent(event);
    }
    
    /**
     * Log quantum state changes
     */
    logQuantumStateChange(address, oldState, newState, observer) {
        const event = {
            type: 'QuantumStateChange',
            timestamp: Date.now(),
            address: address,
            observer: observer,
            oldState: {
                superposition: oldState.superposition,
                entanglement: oldState.entanglement,
                coherence: oldState.coherence
            },
            newState: {
                superposition: newState.superposition,
                entanglement: newState.entanglement,
                coherence: newState.coherence
            },
            waveFunction: newState.waveFunction
        };
        
        this.writeEvent(event);
    }
    
    /**
     * Log ghost fork activity
     */
    logGhostActivity(ghostId, action, data) {
        const event = {
            type: 'GhostActivity',
            timestamp: Date.now(),
            ghostId: ghostId,
            action: action,
            data: data,
            ephemeral: true
        };
        
        this.writeEvent(event);
    }
    
    /**
     * Log obfuscation events
     */
    logObfuscation(target, level, pattern, bytecodeHash) {
        const event = {
            type: 'Obfuscation',
            timestamp: Date.now(),
            target: target,
            obfuscationLevel: level,
            pattern: pattern,
            bytecodeHash: bytecodeHash,
            entropy: Math.random()
        };
        
        this.writeEvent(event);
    }
    
    /**
     * Write event to log file
     */
    writeEvent(event) {
        try {
            // Add sequence number
            event.sequence = ++this.eventCount;
            
            // Add cryptographic proof
            event.proof = this.generateEventProof(event);
            
            // Convert to JSON and append
            const line = JSON.stringify(event) + '\n';
            
            // Check if rotation needed
            this.checkRotation();
            
            // Write to file
            fs.appendFileSync(this.currentLogFile, line);
            
            // Also write to encrypted shadow log
            this.writeShadowLog(event);
            
        } catch (error) {
            console.error('Failed to write event:', error);
        }
    }
    
    /**
     * Generate cryptographic proof for event
     */
    generateEventProof(event) {
        const crypto = require('crypto');
        const data = JSON.stringify({
            type: event.type,
            timestamp: event.timestamp,
            sequence: event.sequence
        });
        
        return crypto.createHash('sha256').update(data).digest('hex');
    }
    
    /**
     * Write to encrypted shadow log
     */
    writeShadowLog(event) {
        const shadowFile = path.join(this.logDir, 'shadow', `${Date.now()}.enc`);
        const shadowDir = path.dirname(shadowFile);
        
        if (!fs.existsSync(shadowDir)) {
            fs.mkdirSync(shadowDir, { recursive: true });
        }
        
        // Simple XOR encryption for demo
        const key = Buffer.from('SHADOW_LOG_KEY_2024', 'utf8');
        const data = Buffer.from(JSON.stringify(event), 'utf8');
        const encrypted = Buffer.alloc(data.length);
        
        for (let i = 0; i < data.length; i++) {
            encrypted[i] = data[i] ^ key[i % key.length];
        }
        
        fs.writeFileSync(shadowFile, encrypted);
    }
    
    /**
     * Check if log rotation needed
     */
    checkRotation() {
        const stats = fs.statSync(this.currentLogFile);
        
        if (stats.size > this.maxLogSize) {
            this.rotateLog();
        }
    }
    
    /**
     * Rotate log files
     */
    rotateLog() {
        console.log('Rotating log file...');
        
        // Rename current log
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const rotatedFile = path.join(this.logDir, `events_${timestamp}.log`);
        fs.renameSync(this.currentLogFile, rotatedFile);
        
        // Create new log file
        this.currentLogFile = this.getLogFileName();
        this.eventCount = 0;
        
        // Clean old logs
        this.cleanOldLogs();
    }
    
    /**
     * Clean old log files
     */
    cleanOldLogs() {
        const files = fs.readdirSync(this.logDir)
            .filter(f => f.startsWith('events_') && f.endsWith('.log'))
            .map(f => ({
                name: f,
                path: path.join(this.logDir, f),
                time: fs.statSync(path.join(this.logDir, f)).mtime
            }))
            .sort((a, b) => b.time - a.time);
        
        // Keep only recent logs
        if (files.length > this.rotationCount) {
            files.slice(this.rotationCount).forEach(f => {
                fs.unlinkSync(f.path);
                console.log(`Deleted old log: ${f.name}`);
            });
        }
    }
    
    /**
     * Get current log file name
     */
    getLogFileName() {
        return path.join(this.logDir, 'events_current.log');
    }
    
    /**
     * Query logs
     */
    queryLogs(filter = {}) {
        const results = [];
        const files = [this.currentLogFile];
        
        // Add rotated files if searching historical data
        if (filter.historical) {
            const rotatedFiles = fs.readdirSync(this.logDir)
                .filter(f => f.startsWith('events_') && f.endsWith('.log'))
                .map(f => path.join(this.logDir, f));
            files.push(...rotatedFiles);
        }
        
        for (const file of files) {
            if (!fs.existsSync(file)) continue;
            
            const lines = fs.readFileSync(file, 'utf8').split('\n');
            
            for (const line of lines) {
                if (!line) continue;
                
                try {
                    const event = JSON.parse(line);
                    
                    // Apply filters
                    if (filter.type && event.type !== filter.type) continue;
                    if (filter.address && event.address !== filter.address && 
                        event.from !== filter.address && event.to !== filter.address) continue;
                    if (filter.startTime && event.timestamp < filter.startTime) continue;
                    if (filter.endTime && event.timestamp > filter.endTime) continue;
                    
                    results.push(event);
                    
                } catch (e) {
                    // Skip malformed lines
                }
            }
        }
        
        return results;
    }
    
    /**
     * Generate forensics report
     */
    generateForensicsReport(address) {
        const events = this.queryLogs({ address: address, historical: true });
        
        const report = {
            address: address,
            totalEvents: events.length,
            firstSeen: events.length > 0 ? new Date(events[0].timestamp) : null,
            lastSeen: events.length > 0 ? new Date(events[events.length - 1].timestamp) : null,
            eventTypes: {},
            suspiciousActivities: [],
            quantumStates: [],
            totalVolume: 0
        };
        
        for (const event of events) {
            // Count event types
            report.eventTypes[event.type] = (report.eventTypes[event.type] || 0) + 1;
            
            // Track suspicious activities
            if (event.type === 'SuspiciousActivity') {
                report.suspiciousActivities.push({
                    timestamp: event.timestamp,
                    score: event.suspicionScore,
                    action: event.actionTaken
                });
            }
            
            // Track quantum states
            if (event.type === 'QuantumStateChange') {
                report.quantumStates.push({
                    timestamp: event.timestamp,
                    state: event.newState
                });
            }
            
            // Calculate volume
            if (event.type === 'Transfer' && event.amount) {
                report.totalVolume += parseInt(event.amount);
            }
        }
        
        return report;
    }
}

// Singleton instance
let instance = null;

module.exports = {
    getInstance: (config) => {
        if (!instance) {
            instance = new EventLogger(config);
        }
        return instance;
    },
    EventLogger
};