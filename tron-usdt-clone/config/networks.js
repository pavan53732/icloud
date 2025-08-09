module.exports = {
    mainnet: {
        fullNode: 'https://api.trongrid.io',
        solidityNode: 'https://api.trongrid.io',
        eventServer: 'https://api.trongrid.io',
        network_id: '1',
        gasPrice: 140,
        from: process.env.DEPLOYER_ADDRESS
    },
    shasta: {
        fullNode: 'https://api.shasta.trongrid.io',
        solidityNode: 'https://api.shasta.trongrid.io',
        eventServer: 'https://api.shasta.trongrid.io',
        network_id: '2',
        gasPrice: 140,
        from: process.env.DEPLOYER_ADDRESS
    },
    nile: {
        fullNode: 'https://nile.trongrid.io',
        solidityNode: 'https://nile.trongrid.io',
        eventServer: 'https://event.nileex.io',
        network_id: '3',
        gasPrice: 140,
        from: process.env.DEPLOYER_ADDRESS
    },
    development: {
        fullNode: 'http://127.0.0.1:9090',
        solidityNode: 'http://127.0.0.1:9090',
        eventServer: 'http://127.0.0.1:9090',
        network_id: '9',
        gasPrice: 140,
        from: process.env.DEPLOYER_ADDRESS
    }
};