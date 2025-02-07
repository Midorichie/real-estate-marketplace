// tests/property-nft.test.ts
import { 
  Clarinet,
  Tx,
  Chain,
  Account,
  types,
  assertEquals,
  describe,
  it,
  beforeEach
} from './deps.ts';

describe('property-nft', () => {
  let chain: Chain;
  let deployer: Account;
  let wallet1: Account;
  let wallet2: Account;

  beforeEach(() => {
    chain = new Chain();
    deployer = chain.createAccount();
    wallet1 = chain.createAccount();
    wallet2 = chain.createAccount();
  });

  describe('set-property-metadata', () => {
    it('successfully creates a new property', () => {
      const result = chain.mineBlock([
        Tx.contractCall(
          'property-nft',
          'set-property-metadata',
          [
            types.utf8('123 Main St'),
            types.uint(100000),
            types.some(types.utf8('Beautiful property')),
            types.list([types.utf8('3 beds'), types.utf8('2 baths')])
          ],
          wallet1.address
        )
      ]).receipts[0].result;

      assertEquals(result, types.ok(types.uint(1)));
    });

    it('fails with invalid price', () => {
      const result = chain.mineBlock([
        Tx.contractCall(
          'property-nft',
          'set-property-metadata',
          [
            types.utf8('123 Main St'),
            types.uint(0),
            types.some(types.utf8('Beautiful property')),
            types.list([])
          ],
          wallet1.address
        )
      ]).receipts[0].result;

      assertEquals(result, types.err(types.uint(103)));
    });

    it('fails with empty location', () => {
      const result = chain.mineBlock([
        Tx.contractCall(
          'property-nft',
          'set-property-metadata',
          [
            types.utf8(''),
            types.uint(100000),
            types.some(types.utf8('Beautiful property')),
            types.list([])
          ],
          wallet1.address
        )
      ]).receipts[0].result;

      assertEquals(result, types.err(types.uint(106)));
    });
  });

  describe('update-price', () => {
    it('successfully updates property price', () => {
      // First create a property
      chain.mineBlock([
        Tx.contractCall(
          'property-nft',
          'set-property-metadata',
          [
            types.utf8('123 Main St'),
            types.uint(100000),
            types.some(types.utf8('Beautiful property')),
            types.list([])
          ],
          wallet1.address
        )
      ]);

      // Then update its price
      const result = chain.mineBlock([
        Tx.contractCall(
          'property-nft',
          'update-price',
          [types.uint(1), types.uint(150000)],
          wallet1.address
        )
      ]).receipts[0].result;

      assertEquals(result, types.ok(types.bool(true)));
    });

    it('fails when non-owner tries to update price', () => {
      // First create a property
      chain.mineBlock([
        Tx.contractCall(
          'property-nft',
          'set-property-metadata',
          [
            types.utf8('123 Main St'),
            types.uint(100000),
            types.some(types.utf8('Beautiful property')),
            types.list([])
          ],
          wallet1.address
        )
      ]);

      // Try to update price from different wallet
      const result = chain.mineBlock([
        Tx.contractCall(
          'property-nft',
          'update-price',
          [types.uint(1), types.uint(150000)],
          wallet2.address
        )
      ]).receipts[0].result;

      assertEquals(result, types.err(types.uint(105)));
    });
  });

  describe('transfer', () => {
    it('successfully transfers property', () => {
      // First create a property
      chain.mineBlock([
        Tx.contractCall(
          'property-nft',
          'set-property-metadata',
          [
            types.utf8('123 Main St'),
            types.uint(100000),
            types.some(types.utf8('Beautiful property')),
            types.list([])
          ],
          wallet1.address
        )
      ]);

      // Then transfer it
      const result = chain.mineBlock([
        Tx.contractCall(
          'property-nft',
          'transfer',
          [
            types.uint(1),
            types.principal(wallet1.address),
            types.principal(wallet2.address)
          ],
          wallet1.address
        )
      ]).receipts[0].result;

      assertEquals(result, types.ok(types.bool(true)));
    });

    it('updates property counts after transfer', () => {
      // Create property
      chain.mineBlock([
        Tx.contractCall(
          'property-nft',
          'set-property-metadata',
          [
            types.utf8('123 Main St'),
            types.uint(100000),
            types.some(types.utf8('Beautiful property')),
            types.list([])
          ],
          wallet1.address
        )
      ]);

      // Transfer property
      chain.mineBlock([
        Tx.contractCall(
          'property-nft',
          'transfer',
          [
            types.uint(1),
            types.principal(wallet1.address),
            types.principal(wallet2.address)
          ],
          wallet1.address
        )
      ]);

      // Check counts
      const wallet1Count = chain.callReadOnlyFn(
        'property-nft',
        'get-property-count',
        [types.principal(wallet1.address)],
        wallet1.address
      ).result;

      const wallet2Count = chain.callReadOnlyFn(
        'property-nft',
        'get-property-count',
        [types.principal(wallet2.address)],
        wallet2.address
      ).result;

      assertEquals(wallet1Count, types.ok(types.uint(0)));
      assertEquals(wallet2Count, types.ok(types.uint(1)));
    });
  });
});
