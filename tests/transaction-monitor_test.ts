import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: "transaction-sentinel: Register Transaction",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;

    let block = chain.mineBlock([
      Tx.contractCall('transaction-monitor', 'register-transaction', [
        types.principal(wallet2.address),
        types.uint(1000),
        types.ascii('STX'),
        types.ascii('pending'),
        types.ascii('transfer')
      ], deployer.address)
    ]);

    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    block.receipts[0].result.expectOk().expectUint(1);
  }
});

Clarinet.test({
  name: "transaction-sentinel: Register Verifier",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;

    let block = chain.mineBlock([
      Tx.contractCall('transaction-monitor', 'register-verifier', [
        types.ascii('Transaction Validator'),
        types.ascii('compliance')
      ], wallet1.address)
    ]);

    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
  }
});

Clarinet.test({
  name: "transaction-sentinel: Submit Verification",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;

    let block = chain.mineBlock([
      Tx.contractCall('transaction-monitor', 'register-verifier', [
        types.ascii('Transaction Validator'),
        types.ascii('compliance')
      ], wallet1.address),
      Tx.contractCall('transaction-monitor', 'register-transaction', [
        types.principal(wallet2.address),
        types.uint(1000),
        types.ascii('STX'),
        types.ascii('pending'),
        types.ascii('transfer')
      ], deployer.address),
      Tx.contractCall('transaction-monitor', 'submit-verification', [
        types.uint(1),
        types.ascii('verified'),
        types.ascii('Transaction looks valid')
      ], wallet1.address)
    ]);

    assertEquals(block.receipts.length, 3);
    block.receipts[2].result.expectOk().expectUint(1);
  }
});

Clarinet.test({
  name: "transaction-sentinel: Update Transaction Status",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet2 = accounts.get('wallet_2')!;

    let block = chain.mineBlock([
      Tx.contractCall('transaction-monitor', 'register-transaction', [
        types.principal(wallet2.address),
        types.uint(1000),
        types.ascii('STX'),
        types.ascii('pending'),
        types.ascii('transfer')
      ], deployer.address),
      Tx.contractCall('transaction-monitor', 'update-transaction-status', [
        types.uint(1),
        types.ascii('completed')
      ], deployer.address)
    ]);

    assertEquals(block.receipts.length, 2);
    block.receipts[1].result.expectOk().expectBool(true);
  }
});