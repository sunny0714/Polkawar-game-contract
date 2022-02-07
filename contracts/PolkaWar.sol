// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ReentrancyGuard.sol";

contract PolkaWar is Ownable, ReentrancyGuard {

    IERC20 public polkaWarToken;
    uint256 public rewardMultiplier;
    enum GameState { Opening, Waiting, Running }

    constructor(address _tokenAddress) {
        polkaWarToken = IERC20(_tokenAddress);
        rewardMultiplier = 90;
    }

    struct GamePool {
        uint256 id;
        GameState state;
        uint256 tokenAmount; // token amount needed to enter each pool
        address[] player;
    }

    GamePool[] public pools;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event LogClaimAward(uint256 indexed pid, address indexed winnerAddress, uint256 award);

    // get number of games
    function poolLength() external view returns (uint256) {
        return pools.length;
    }

    // add pool
    function addPool(
        uint256 _tokenAmount
    ) external onlyOwner {
        pools.push(
            GamePool({
                id : pools.length + 1,
                state : GameState.Opening,
                tokenAmount : _tokenAmount,
                player : new address[](0)
            })
        );
    }

    // update pool
    function updatePool(
        uint256 _pid,
        uint256 _tokenAmount
    ) external onlyOwner {
        uint256 poolIndex = _pid - 1;
        if(_tokenAmount > 0) {
            pools[poolIndex].tokenAmount = _tokenAmount;
        }
    }

    // bet game
    function bet(uint256 _pid) external {
        uint256 poolIndex = _pid - 1;
        // check balance
        require(polkaWarToken.balanceOf(msg.sender) >= pools[poolIndex].tokenAmount, "insufficient funds");
        // check game status
        require(pools[poolIndex].state != GameState.Running, "game is running");
        // add user
        if(pools[poolIndex].state == GameState.Opening) {
            pools[poolIndex].player.push(msg.sender);
            pools[poolIndex].state = GameState.Waiting;
        } else if(pools[poolIndex].state == GameState.Waiting) {
            pools[poolIndex].player.push(msg.sender);
            pools[poolIndex].state = GameState.Running;
        }
        // deposit token
        polkaWarToken.transferFrom(msg.sender, address(this), pools[poolIndex].tokenAmount);
        emit Transfer(msg.sender, address(this), pools[poolIndex].tokenAmount);
    }

    // get game players
    function getGamePlayers(uint256 pid) external view returns (address[] memory) {
        return pools[pid - 1].player;        
    }

    // claim award
    function claimAward(uint256 _pid, address _winnerAddress) external onlyOwner nonReentrant {
        uint256 poolIndex = _pid - 1;
        // check game status
        require(pools[poolIndex].state == GameState.Running, "no valid time");
        require(pools[poolIndex].player[0] == _winnerAddress || pools[poolIndex].player[1] == _winnerAddress, "player not found");
        // send award
        uint256 award = pools[poolIndex].tokenAmount * 2 * rewardMultiplier / 100;
        uint256 gasFee = pools[poolIndex].tokenAmount * 2 * (100 - rewardMultiplier) / 100;
        polkaWarToken.transfer(_winnerAddress, award);
        polkaWarToken.transfer(msg.sender, gasFee);
        emit LogClaimAward(_pid, _winnerAddress, award);
        // initialize game
        pools[poolIndex].state = GameState.Opening;
        pools[poolIndex].player = new address[](0);
    }

    // withdraw funds
    function withdrawFund() external onlyOwner {
        uint256 balance = polkaWarToken.balanceOf(address(this));
        require(balance > 0, "not enough fund");
        polkaWarToken.transfer(msg.sender, balance);
    }
}