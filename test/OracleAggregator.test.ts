import { time, loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

/**
 * Deploy OracleAggregator with mock oracles.
 */
async function deployOracleAggregatorFixture() {
  const [owner, authorizedConsumer, otherAccount] = await hre.ethers.getSigners();

  // Deploy mock oracles
  const ChainlinkPriceFeedMock = await hre.ethers.getContractFactory("ChainlinkLikePriceFeedMock");
  const ChronicleOracleMock = await hre.ethers.getContractFactory("ChronicleOracleMock");
  const RedstonePriceFeedMock = await hre.ethers.getContractFactory("ChainlinkLikePriceFeedMock");

  const chainlinkMock = await ChainlinkPriceFeedMock.deploy();
  const chronicleMock = await ChronicleOracleMock.deploy();
  const redstoneMock = await RedstonePriceFeedMock.deploy();

  const chainlinkAddr = await chainlinkMock.getAddress();
  const chronicleAddr = await chronicleMock.getAddress();
  const redstoneAddr = await redstoneMock.getAddress();

  // Deploy OracleAggregatorMock
  const OracleAggregator = await hre.ethers.getContractFactory("OracleAggregatorMock");
  const aggregator = await OracleAggregator.deploy(chainlinkAddr, chronicleAddr, redstoneAddr, 25 * 3600, owner.address);

  return {
    aggregator,
    chainlinkMock,
    chronicleMock,
    redstoneMock,
    owner,
    authorizedConsumer,
    otherAccount,
  };
}

/**
 * Test cases for OracleAggregator.
 */
describe("OracleAggregator", function () {
  describe("Ignoring reverted oracles", function () {
    it("Should return the median value from 3 oracles", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      // Set mock oracle responses
      const mockRoundId = 0;
      await chainlinkMock.setValue(100, mockRoundId, blockTimestamp);
      await chronicleMock.setValue(200, blockTimestamp);
      await redstoneMock.setValue(300, mockRoundId, blockTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(200); // Median of [100, 200, 300]
      expect(goodOraclesCount).to.equal(3);
    });

    it("Should return the median value from 2 oracles (chainlink, chronicle)", async function () {
      const { aggregator, chainlinkMock, chronicleMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      // Set mock oracle responses
      const mockRoundId = 0;
      await chainlinkMock.setValue(150, mockRoundId, blockTimestamp);
      await chronicleMock.setValue(100, blockTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(125); // Median of [150, 100]
      expect(goodOraclesCount).to.equal(2);
    });

    it("Should return the median value from 2 oracles (chainlink, redstone)", async function () {
      const { aggregator, chainlinkMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      // Set mock oracle responses
      const mockRoundId = 0;
      await chainlinkMock.setValue(150, mockRoundId, blockTimestamp);
      await redstoneMock.setValue(150, mockRoundId, blockTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(150); // Median of [150, 150]
      expect(goodOraclesCount).to.equal(2);
    });

    it("Should return the median value from 2 oracles (chronicle, redstone)", async function () {
      const { aggregator, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      // Set mock oracle responses
      const mockRoundId = 0;
      await chronicleMock.setValue(148, blockTimestamp);
      await redstoneMock.setValue(150, mockRoundId, blockTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(149); // Median of [148, 150]
      expect(goodOraclesCount).to.equal(2);
    });

    it("Should work only with redstone", async function () {
      const { aggregator, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      // Set mock oracle responses
      const mockRoundId = 0;
      await redstoneMock.setValue(42, mockRoundId, blockTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(42); // Median of [42]
      expect(goodOraclesCount).to.equal(1);
    });

    it("Should work only with chainlink", async function () {
      const { aggregator, chainlinkMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      // Set mock oracle responses
      const mockRoundId = 0;
      await chainlinkMock.setValue(420, mockRoundId, blockTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(420); // Median of [420]
      expect(goodOraclesCount).to.equal(1);
    });

    it("Should work only with chronicle", async function () {
      const { aggregator, chronicleMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      // Set mock oracle responses
      await chronicleMock.setValue(420, blockTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(420); // Median of [420]
      expect(goodOraclesCount).to.equal(1);
    });

    it("Should revert with no working oracles", async function () {
      const { aggregator, chainlinkMock } = await loadFixture(deployOracleAggregatorFixture);
      await expect(aggregator.getAggregatedOracleValue()).to.be.revertedWithCustomError(aggregator, "CanNotPickMedianOfEmptyArray");
    });
  });

  describe("Handling invalid values", function () {
    it("Should work properly with one outlier", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      // Set mock oracle responses
      const mockRoundId = 0;
      await chainlinkMock.setValue(100, mockRoundId, blockTimestamp);
      await chronicleMock.setValue(99, blockTimestamp);
      await redstoneMock.setValue(100000, mockRoundId, blockTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(100); // Median of [100, 99, 100000]
      expect(goodOraclesCount).to.equal(3);
    });

    it("Should work properly with an invalid value from chronicle", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      // Set mock oracle responses
      const mockRoundId = 0;
      await chainlinkMock.setValue(100, mockRoundId, blockTimestamp);
      await chronicleMock.setValue(0, blockTimestamp); // 0 value will cause reverting
      await redstoneMock.setValue(98, mockRoundId, blockTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(99); // Median of [100, 98]
      expect(goodOraclesCount).to.equal(2);
    });
  });

  describe("Ignoring old oracle values", function () {
    it("Should accept chainlink at the age threshold and expire it one second later", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();
      const chainlinkTimestamp = blockTimestamp - 10;
      const ageThreshold = Number(await aggregator.getAgeThreshold());
      const expiryTimestamp = chainlinkTimestamp + ageThreshold;

      const mockRoundId = 0;
      await chainlinkMock.setValue(100, mockRoundId, chainlinkTimestamp);
      await chronicleMock.setValue(200, blockTimestamp);
      await redstoneMock.setValue(500, mockRoundId, blockTimestamp);

      await time.increaseTo(expiryTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(200); // Median of [100, 200, 500]
      expect(goodOraclesCount).to.equal(3);

      await time.increase(1);

      const [valueAfterExpiry, goodOraclesCountAfterExpiry] = await aggregator.getAggregatedOracleValue();

      expect(valueAfterExpiry).to.equal(350); // Median of [200, 500]
      expect(goodOraclesCountAfterExpiry).to.equal(2);
      expect(await aggregator.latestAnswer()).to.equal(350);

      const [, answer, , updatedAt] = await aggregator.latestRoundData();

      expect(answer).to.equal(350);
      expect(updatedAt).to.equal(expiryTimestamp + 1);
    });

    it("Should accept chronicle at the age threshold and expire it one second later", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();
      const chronicleTimestamp = blockTimestamp - 10;
      const ageThreshold = Number(await aggregator.getAgeThreshold());
      const expiryTimestamp = chronicleTimestamp + ageThreshold;

      const mockRoundId = 0;
      await chainlinkMock.setValue(100, mockRoundId, blockTimestamp);
      await chronicleMock.setValue(200, chronicleTimestamp);
      await redstoneMock.setValue(500, mockRoundId, blockTimestamp);

      await time.increaseTo(expiryTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(200); // Median of [100, 200, 500]
      expect(goodOraclesCount).to.equal(3);

      await time.increase(1);

      const [valueAfterExpiry, goodOraclesCountAfterExpiry] = await aggregator.getAggregatedOracleValue();

      expect(valueAfterExpiry).to.equal(300); // Median of [100, 500]
      expect(goodOraclesCountAfterExpiry).to.equal(2);
      expect(await aggregator.latestAnswer()).to.equal(300);

      const [, answer, , updatedAt] = await aggregator.latestRoundData();

      expect(answer).to.equal(300);
      expect(updatedAt).to.equal(expiryTimestamp + 1);
    });

    it("Should accept redstone at the age threshold and expire it one second later", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();
      const redstoneTimestamp = blockTimestamp - 10;
      const ageThreshold = Number(await aggregator.getAgeThreshold());
      const expiryTimestamp = redstoneTimestamp + ageThreshold;

      const mockRoundId = 0;
      await chainlinkMock.setValue(100, mockRoundId, blockTimestamp);
      await chronicleMock.setValue(200, blockTimestamp);
      await redstoneMock.setValue(500, mockRoundId, redstoneTimestamp);

      await time.increaseTo(expiryTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(200); // Median of [100, 200, 500]
      expect(goodOraclesCount).to.equal(3);

      await time.increase(1);

      const [valueAfterExpiry, goodOraclesCountAfterExpiry] = await aggregator.getAggregatedOracleValue();

      expect(valueAfterExpiry).to.equal(150); // Median of [100, 200]
      expect(goodOraclesCountAfterExpiry).to.equal(2);
      expect(await aggregator.latestAnswer()).to.equal(150);

      const [, answer, , updatedAt] = await aggregator.latestRoundData();

      expect(answer).to.equal(150);
      expect(updatedAt).to.equal(expiryTimestamp + 1);
    });

    it("Should ignore too old data from chronicle", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      // Set mock oracle responses
      const mockRoundId = 0;
      await chainlinkMock.setValue(100, mockRoundId, blockTimestamp);
      await chronicleMock.setValue(100, blockTimestamp - (25 * 3600 + 1));
      await redstoneMock.setValue(98, mockRoundId, blockTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(99); // Median of [100, 98]
      expect(goodOraclesCount).to.equal(2);
    });

    it("Should ignore too old data from redstone", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      const mockRoundId = 0;
      await chainlinkMock.setValue(100, mockRoundId, blockTimestamp);
      await chronicleMock.setValue(100, blockTimestamp);
      await redstoneMock.setValue(98, mockRoundId, blockTimestamp - (25 * 3600 + 1));

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(100); // Median of [100, 100]
      expect(goodOraclesCount).to.equal(2);
    });

    it("Should ignore too old data from chainlink", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      const mockRoundId = 0;
      await chainlinkMock.setValue(101, mockRoundId, blockTimestamp - (25 * 3600 + 1));
      await chronicleMock.setValue(100, blockTimestamp);
      await redstoneMock.setValue(98, mockRoundId, blockTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(99); // Median of [100, 98]
      expect(goodOraclesCount).to.equal(2);
    });

    it("Should ignore too old data from redstone and chronicle", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      const mockRoundId = 0;
      await chainlinkMock.setValue(101, mockRoundId, blockTimestamp - (25 * 3600 - 10)); // Not too old
      await chronicleMock.setValue(100, blockTimestamp - (25 * 3600 + 1)); // Too old
      await redstoneMock.setValue(98, mockRoundId, blockTimestamp - (25 * 3600 + 1)); // Too old

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(101); // Median of [101]
      expect(goodOraclesCount).to.equal(1);
    });
  });

  describe("Ignoring oracles trying to perform consume too much gas", function () {
    it("Should ignore chronicle if it consumes too much gas", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      // Set mock oracle responses
      const mockRoundId = 0;
      await chainlinkMock.setValue(100, mockRoundId, blockTimestamp);
      await chronicleMock.setValue(250, blockTimestamp);
      await chronicleMock.enableGasConsumingMode();
      await redstoneMock.setValue(300, mockRoundId, blockTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(200); // Median of [100, 300]
      expect(goodOraclesCount).to.equal(2);
    });

    it("Should ignore chainlink if it consumes too much gas", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      // Set mock oracle responses
      const mockRoundId = 0;
      await chainlinkMock.setValue(100, mockRoundId, blockTimestamp);
      await chainlinkMock.enableGasConsumingMode();
      await chronicleMock.setValue(250, blockTimestamp);
      await redstoneMock.setValue(300, mockRoundId, blockTimestamp);

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(275); // Median of [250, 300]
      expect(goodOraclesCount).to.equal(2);
    });

    it("Should ignore redstone if it consumes too much gas", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      // Set mock oracle responses
      const mockRoundId = 0;
      await chainlinkMock.setValue(100, mockRoundId, blockTimestamp);
      await chronicleMock.setValue(250, blockTimestamp);
      await redstoneMock.setValue(300, mockRoundId, blockTimestamp);
      await redstoneMock.enableGasConsumingMode();

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(175); // Median of [100, 250]
      expect(goodOraclesCount).to.equal(2);
    });

    it("Should ignore redstone and chronicle if they consume too much gas", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      // Set mock oracle responses
      const mockRoundId = 0;
      await chainlinkMock.setValue(100, mockRoundId, blockTimestamp);
      await chronicleMock.setValue(250, blockTimestamp);
      await chronicleMock.enableGasConsumingMode();
      await redstoneMock.setValue(300, mockRoundId, blockTimestamp);
      await redstoneMock.enableGasConsumingMode();

      const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

      expect(value).to.equal(100); // Median of [100]
      expect(goodOraclesCount).to.equal(1);
    });

    it("Should measure used gas for different cases", async function () {
      const { aggregator, chainlinkMock, chronicleMock, redstoneMock } = await loadFixture(deployOracleAggregatorFixture);

      const blockTimestamp = await time.latest();

      const mockRoundId = 0;
      await chainlinkMock.setValue(100, mockRoundId, blockTimestamp);
      await chronicleMock.setValue(250, blockTimestamp);
      await redstoneMock.setValue(300, mockRoundId, blockTimestamp);
    
      const tx1Receipt = await (await aggregator.readOracleForGasBenchmark()).wait();
      console.log(`Gas used with all no OOG: ${tx1Receipt.gasUsed}`);

      await chainlinkMock.enableGasConsumingMode();
      const tx2Receipt = await (await aggregator.readOracleForGasBenchmark()).wait();
      console.log(`Gas used with 1 OOG attack: ${tx2Receipt.gasUsed}`);

      await chronicleMock.enableGasConsumingMode();
      const tx3Receipt = await (await aggregator.readOracleForGasBenchmark()).wait();
      console.log(`Gas used with 1 OOG attack: ${tx3Receipt.gasUsed}`);
    });
  });
});
