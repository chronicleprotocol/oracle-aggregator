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
  const aggregator = await OracleAggregator.deploy(chainlinkAddr, chronicleAddr, redstoneAddr, 10000, owner.address);

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
  describe("Deployment", function () {
    it("Should deploy with correct initial state", async function () {
      const { aggregator } = await loadFixture(deployOracleAggregatorFixture);

      // const valueWithStatus = await aggregator.getAggregatedOracleValue();

      

      expect(await aggregator.decimals()).to.equal(8);
    });
  });

  describe("Oracle Data Aggregation", function () {
    it("Should return the median value from oracles", async function () {
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

    // it("Should handle missing oracle responses gracefully", async function () {
    //   const { aggregator, chainlinkMock, chronicleMock } = await loadFixture(deployOracleAggregatorFixture);

    //   // Set only two oracles
    //   await chainlinkMock.setLatestAnswer(150);
    //   await chronicleMock.setLatestAnswer(250);

    //   const [value, goodOraclesCount] = await aggregator.getAggregatedOracleValue();

    //   expect(value).to.equal(200); // Median of [150, 250]
    //   expect(goodOraclesCount).to.equal(2);
    // });

    // it("Should revert if no oracles return valid data", async function () {
    //   const { aggregator } = await loadFixture(deployOracleAggregatorFixture);

    //   await expect(aggregator.getAggregatedOracleValue()).to.be.revertedWith("No valid oracle data");
    // });
  });

  // describe("Access Control", function () {
  //   it("Should allow only authorized consumers to call getAggregatedOracleValue", async function () {
  //     const { aggregator, authorizedConsumer, otherAccount } = await loadFixture(deployOracleAggregatorFixture);

  //     // Authorize a consumer
  //     await aggregator.checkAuthorisedDataConsumer(authorizedConsumer.address);

  //     // Call as an authorized consumer
  //     await expect(aggregator.connect(authorizedConsumer).getAggregatedOracleValue()).not.to.be.reverted;

  //     // Call as an unauthorized consumer
  //     await expect(aggregator.connect(otherAccount).getAggregatedOracleValue()).to.be.revertedWith("Not authorized");
  //   });
  // });
});
