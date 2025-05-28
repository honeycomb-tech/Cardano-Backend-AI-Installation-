/**
 * Cardano Backend Integration Example
 * 
 * This example shows how to connect to and use the Cardano backend
 * for dApp development.
 */

import { createClient } from '@supabase/supabase-js'

// Configuration - REPLACE WITH YOUR ACTUAL VALUES
const SUPABASE_URL = 'http://localhost:8000'
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY_HERE' // Get this from your .env file

// Initialize Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

/**
 * Example 1: Get Latest Blocks
 */
async function getLatestBlocks(limit = 10) {
  try {
    const { data, error } = await supabase
      .from('block')
      .select('*')
      .order('slot', { ascending: false })
      .limit(limit)

    if (error) throw error

    console.log('Latest blocks:', data)
    return data
  } catch (error) {
    console.error('Error fetching blocks:', error)
    return null
  }
}

/**
 * Example 2: Get Transactions for an Address
 */
async function getTransactionsForAddress(address, limit = 50) {
  try {
    const { data, error } = await supabase
      .from('tx_out')
      .select(`
        *,
        tx:tx_id (
          hash,
          block:block_id (
            time,
            slot,
            block_no
          )
        )
      `)
      .eq('address', address)
      .order('id', { ascending: false })
      .limit(limit)

    if (error) throw error

    console.log(`Transactions for ${address}:`, data)
    return data
  } catch (error) {
    console.error('Error fetching transactions:', error)
    return null
  }
}

/**
 * Example 3: Get UTXOs for an Address
 */
async function getUTXOsForAddress(address) {
  try {
    // Get unspent outputs
    const { data, error } = await supabase
      .from('tx_out')
      .select(`
        *,
        tx:tx_id (
          hash,
          block:block_id (
            time,
            slot
          )
        )
      `)
      .eq('address', address)
      .is('consumed_by_tx_id', null) // Not spent

    if (error) throw error

    console.log(`UTXOs for ${address}:`, data)
    return data
  } catch (error) {
    console.error('Error fetching UTXOs:', error)
    return null
  }
}

/**
 * Example 4: Monitor New Blocks (Real-time)
 */
function subscribeToNewBlocks(callback) {
  const subscription = supabase
    .channel('blocks')
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'block'
      },
      (payload) => {
        console.log('New block:', payload.new)
        callback(payload.new)
      }
    )
    .subscribe()

  return subscription
}

/**
 * Example 5: Get Pool Information
 */
async function getPoolInfo(poolId) {
  try {
    const { data, error } = await supabase
      .from('pool_hash')
      .select(`
        *,
        pool_update:pool_update (
          *,
          pool_metadata:pool_metadata_ref (
            *
          )
        )
      `)
      .eq('view', poolId)
      .single()

    if (error) throw error

    console.log(`Pool info for ${poolId}:`, data)
    return data
  } catch (error) {
    console.error('Error fetching pool info:', error)
    return null
  }
}

/**
 * Example 6: Get Asset Information
 */
async function getAssetInfo(policyId, assetName) {
  try {
    const { data, error } = await supabase
      .from('multi_asset')
      .select(`
        *,
        policy:policy (
          *
        )
      `)
      .eq('policy.script', policyId)
      .eq('name', assetName)
      .single()

    if (error) throw error

    console.log(`Asset info for ${policyId}.${assetName}:`, data)
    return data
  } catch (error) {
    console.error('Error fetching asset info:', error)
    return null
  }
}

/**
 * Example 7: Get Delegation History
 */
async function getDelegationHistory(stakeAddress, limit = 20) {
  try {
    const { data, error } = await supabase
      .from('delegation')
      .select(`
        *,
        tx:tx_id (
          hash,
          block:block_id (
            time,
            epoch_no
          )
        ),
        pool:pool_id (
          pool_hash:pool_hash (
            view
          )
        )
      `)
      .eq('addr_id.view', stakeAddress)
      .order('id', { ascending: false })
      .limit(limit)

    if (error) throw error

    console.log(`Delegation history for ${stakeAddress}:`, data)
    return data
  } catch (error) {
    console.error('Error fetching delegation history:', error)
    return null
  }
}

/**
 * Example 8: Calculate Address Balance
 */
async function calculateAddressBalance(address) {
  try {
    // Get all UTXOs for the address
    const utxos = await getUTXOsForAddress(address)
    
    if (!utxos) return null

    // Calculate total ADA balance
    const totalLovelace = utxos.reduce((sum, utxo) => {
      return sum + parseInt(utxo.value)
    }, 0)

    // Convert to ADA
    const adaBalance = totalLovelace / 1000000

    // Get native assets
    const assets = {}
    utxos.forEach(utxo => {
      if (utxo.multi_asset) {
        // Parse multi-asset data
        // This would need proper parsing based on your schema
      }
    })

    const balance = {
      address,
      ada: adaBalance,
      lovelace: totalLovelace,
      assets,
      utxoCount: utxos.length
    }

    console.log(`Balance for ${address}:`, balance)
    return balance
  } catch (error) {
    console.error('Error calculating balance:', error)
    return null
  }
}

/**
 * Example Usage
 */
async function main() {
  console.log('🚀 Cardano Backend Integration Example')
  console.log('=====================================')

  // REPLACE WITH YOUR ACTUAL WALLET ADDRESS
  const exampleAddress = 'addr1_YOUR_CARDANO_ADDRESS_HERE'

  try {
    // Get latest blocks
    console.log('\n📦 Latest Blocks:')
    await getLatestBlocks(5)

    // Get transactions for address
    console.log('\n💸 Recent Transactions:')
    await getTransactionsForAddress(exampleAddress, 10)

    // Get UTXOs
    console.log('\n🔗 UTXOs:')
    await getUTXOsForAddress(exampleAddress)

    // Calculate balance
    console.log('\n💰 Balance:')
    await calculateAddressBalance(exampleAddress)

    // Subscribe to new blocks
    console.log('\n🔔 Subscribing to new blocks...')
    const subscription = subscribeToNewBlocks((block) => {
      console.log(`New block #${block.block_no} at slot ${block.slot}`)
    })

    // Clean up subscription after 30 seconds
    setTimeout(() => {
      subscription.unsubscribe()
      console.log('Unsubscribed from block updates')
    }, 30000)

  } catch (error) {
    console.error('Error in main:', error)
  }
}

// Export functions for use in other modules
export {
  supabase,
  getLatestBlocks,
  getTransactionsForAddress,
  getUTXOsForAddress,
  subscribeToNewBlocks,
  getPoolInfo,
  getAssetInfo,
  getDelegationHistory,
  calculateAddressBalance
}

// Run example if this file is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main()
} 