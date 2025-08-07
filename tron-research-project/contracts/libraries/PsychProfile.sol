// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title PsychProfile
 * @dev Psychological profiling and behavioral analysis library
 * Simulates trust, greed, fear, and social dynamics
 */
library PsychProfile {
    // Psychological profile structure
    struct Profile {
        uint256 trust;              // Trust level (0-100)
        uint256 greed;              // Greed factor (0-100)
        uint256 fear;               // Fear index (0-100)
        uint256 awareness;          // Security awareness (0-100)
        uint256 socialProof;        // Influenced by others (0-100)
        uint256 riskTolerance;      // Risk appetite (0-100)
        uint256 experience;         // Crypto experience (0-100)
        uint256 impulsiveness;      // Quick decision tendency (0-100)
        uint256 skepticism;         // Doubt level (0-100)
        uint256 fomo;               // Fear of missing out (0-100)
    }

    // Behavioral pattern structure
    struct Behavior {
        uint256 transactionCount;
        uint256 averageAmount;
        uint256 peakActivity;
        uint256 dormancy;
        uint256 interactionTypes;
        uint256 failedAttempts;
        uint256 successRate;
        uint256 timePattern;
        bool isWhale;
        bool isBot;
    }

    // Social influence structure
    struct SocialInfluence {
        uint256 networkSize;
        uint256 influencerScore;
        uint256 followerBehavior;
        uint256 viralCoefficient;
        uint256 trustNetwork;
        uint256 referralChain;
    }

    /**
     * @dev Initialize a new psychological profile
     */
    function initProfile(address user) internal view returns (Profile memory) {
        uint256 seed = uint256(keccak256(abi.encodePacked(user, block.timestamp)));
        
        return Profile({
            trust: 50 + (seed % 30),           // Base trust 50-80
            greed: 40 + (seed >> 8) % 40,      // Base greed 40-80
            fear: 20 + (seed >> 16) % 30,      // Base fear 20-50
            awareness: 10 + (seed >> 24) % 40,  // Base awareness 10-50
            socialProof: 60 + (seed >> 32) % 30, // Base social 60-90
            riskTolerance: 30 + (seed >> 40) % 50,
            experience: (seed >> 48) % 100,
            impulsiveness: 40 + (seed >> 56) % 40,
            skepticism: 20 + (seed >> 64) % 60,
            fomo: 50 + (seed >> 72) % 40
        });
    }

    /**
     * @dev Update profile based on transaction behavior
     */
    function updateProfile(
        Profile memory profile,
        Behavior memory behavior
    ) internal pure returns (Profile memory) {
        // High transaction count increases experience
        if (behavior.transactionCount > 100) {
            profile.experience = min(100, profile.experience + 10);
        }

        // Large amounts increase greed but also fear
        if (behavior.averageAmount > 10000 * 1e6) { // > 10k USDT
            profile.greed = min(100, profile.greed + 5);
            profile.fear = min(100, profile.fear + 3);
        }

        // Failed attempts increase skepticism
        if (behavior.failedAttempts > 0) {
            profile.skepticism = min(100, profile.skepticism + behavior.failedAttempts * 2);
            profile.trust = subSafe(profile.trust, behavior.failedAttempts);
        }

        // Success increases trust and reduces fear
        if (behavior.successRate > 80) {
            profile.trust = min(100, profile.trust + 5);
            profile.fear = subSafe(profile.fear, 5);
        }

        // Whale behavior
        if (behavior.isWhale) {
            profile.awareness = min(100, profile.awareness + 20);
            profile.riskTolerance = min(100, profile.riskTolerance + 10);
        }

        return profile;
    }

    /**
     * @dev Calculate decision probability based on profile
     */
    function decisionProbability(
        Profile memory profile,
        uint256 amount,
        uint256 marketSentiment
    ) internal pure returns (uint256) {
        // Base probability influenced by greed and FOMO
        uint256 probability = (profile.greed + profile.fomo) / 2;

        // Adjust for trust
        probability = (probability * profile.trust) / 100;

        // Reduce by fear and skepticism
        uint256 reduction = (profile.fear + profile.skepticism) / 2;
        probability = subSafe(probability, reduction / 2);

        // Social proof influence
        probability = (probability * (100 + profile.socialProof)) / 200;

        // Market sentiment adjustment
        probability = (probability * (100 + marketSentiment)) / 200;

        // Risk tolerance for large amounts
        if (amount > 1000 * 1e6) { // > 1k USDT
            probability = (probability * profile.riskTolerance) / 100;
        }

        return min(100, probability);
    }

    /**
     * @dev Apply social influence to profile
     */
    function applySocialInfluence(
        Profile memory profile,
        SocialInfluence memory social
    ) internal pure returns (Profile memory) {
        // Network effect on trust
        if (social.networkSize > 10) {
            profile.trust = min(100, profile.trust + social.networkSize / 10);
        }

        // Influencer impact
        if (social.influencerScore > 50) {
            profile.socialProof = min(100, profile.socialProof + 10);
            profile.fomo = min(100, profile.fomo + 5);
        }

        // Viral behavior increases impulsiveness
        if (social.viralCoefficient > 2) {
            profile.impulsiveness = min(100, profile.impulsiveness + 10);
        }

        // Trust network reinforcement
        profile.trust = (profile.trust * (100 + social.trustNetwork)) / 200;

        return profile;
    }

    /**
     * @dev Calculate manipulation vector
     */
    function manipulationVector(
        Profile memory profile
    ) internal pure returns (uint256 vector, string memory approach) {
        // Identify strongest psychological lever
        uint256 maxLever = profile.greed;
        approach = "greed";

        if (profile.fomo > maxLever) {
            maxLever = profile.fomo;
            approach = "fomo";
        }

        if (profile.trust > 70 && profile.skepticism < 30) {
            maxLever = profile.trust;
            approach = "trust";
        }

        if (profile.socialProof > 80) {
            maxLever = profile.socialProof;
            approach = "social";
        }

        // Calculate manipulation effectiveness
        vector = maxLever * (100 - profile.awareness) / 100;
        vector = vector * (100 - profile.skepticism) / 100;

        return (vector, approach);
    }

    /**
     * @dev Predict behavior based on profile
     */
    function predictBehavior(
        Profile memory profile,
        uint256 timeOfDay,
        uint256 dayOfWeek
    ) internal pure returns (uint256 activityLevel) {
        // Base activity from impulsiveness and experience
        activityLevel = (profile.impulsiveness + profile.experience) / 2;

        // Time-based adjustments
        if (timeOfDay >= 9 && timeOfDay <= 17) { // Business hours
            activityLevel = activityLevel * 120 / 100;
        } else if (timeOfDay >= 21 || timeOfDay <= 2) { // Late night
            activityLevel = activityLevel * 80 / 100;
        }

        // Weekend adjustment
        if (dayOfWeek == 0 || dayOfWeek == 6) {
            activityLevel = activityLevel * 90 / 100;
        }

        // Fear reduces activity
        activityLevel = activityLevel * (100 - profile.fear / 2) / 100;

        return activityLevel;
    }

    /**
     * @dev Generate personalized message based on profile
     */
    function personalizedApproach(
        Profile memory profile
    ) internal pure returns (uint256 approachType) {
        (, string memory approach) = manipulationVector(profile);
        
        if (keccak256(bytes(approach)) == keccak256(bytes("greed"))) {
            return 1; // Profit-focused messaging
        } else if (keccak256(bytes(approach)) == keccak256(bytes("fomo"))) {
            return 2; // Urgency and scarcity
        } else if (keccak256(bytes(approach)) == keccak256(bytes("trust"))) {
            return 3; // Authority and credibility
        } else if (keccak256(bytes(approach)) == keccak256(bytes("social"))) {
            return 4; // Peer pressure and testimonials
        }
        
        return 0; // Default approach
    }

    /**
     * @dev Helper: Safe subtraction
     */
    function subSafe(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : 0;
    }

    /**
     * @dev Helper: Minimum of two values
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}