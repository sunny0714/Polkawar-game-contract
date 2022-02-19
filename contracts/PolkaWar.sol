// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ReentrancyGuard.sol";

contract PolkaWar is Ownable, ReentrancyGuard {

    IERC20 public polkaWarToken;
    uint256 public rewardMultiplier;
    enum GameState { Opening, Waiting, Running, Finished }

    constructor(address _tokenAddress) {
        polkaWarToken = IERC20(_tokenAddress);
        rewardMultiplier = 90;
    }

    struct GamePool {
        uint256 id;
        GameState state;
        uint256 tokenAmount; // token amount needed to enter each pool
        address[] player;
        address winner;
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
                id : pools.length,
                state : GameState.Opening,
                tokenAmount : _tokenAmount,
                player : new address[](0),
                winner : address(0)
            })
        );
    }

    // update pool
    function updatePool(
        uint256 _pid,
        uint256 _tokenAmount
    ) external onlyOwner {
        if(_tokenAmount > 0) {
            pools[_pid].tokenAmount = _tokenAmount;
        }
    }

    // bet game
    function bet(uint256 _pid) external {
        // check balance
        require(polkaWarToken.balanceOf(msg.sender) >= pools[_pid].tokenAmount, "insufficient funds");
        // check game status
        require(pools[_pid].state != GameState.Running, "game is running");
        // add user
        if(pools[_pid].state == GameState.Opening) {
            pools[_pid].player.push(msg.sender);
            pools[_pid].state = GameState.Waiting;
        } else if(pools[_pid].state == GameState.Waiting) {
            pools[_pid].player.push(msg.sender);
            pools[_pid].state = GameState.Running;
        }
        // deposit token
        polkaWarToken.transferFrom(msg.sender, address(this), pools[_pid].tokenAmount);
        emit Transfer(msg.sender, address(this), pools[_pid].tokenAmount);
    }

    // get game players
    function getGamePlayers(uint256 _pid) external view returns (address[] memory) {
        return pools[_pid].player;        
    }

    // set winner
    function updateGameStatus(uint256 _pid, address _winnerAddress) external onlyOwner {
        // check game status
        require(pools[_pid].state == GameState.Running, "no valid time");
        require(pools[_pid].player[0] == _winnerAddress || pools[_pid].player[1] == _winnerAddress, "player not found");
        // update game status
        pools[_pid].state = GameState.Finished;
        pools[_pid].winner = _winnerAddress;
    }

    // claim award
    function claimAward(uint256 _pid) external nonReentrant {
        // check game status
        require(pools[_pid].state == GameState.Finished, "no valid time");
        require(pools[_pid].player[0] == msg.sender || pools[_pid].player[1] == msg.sender, "player not found");
        require(pools[_pid].winner == msg.sender, "not winner");
        // send award
        uint256 award = pools[_pid].tokenAmount * 2 * rewardMultiplier / 100;
        uint256 gasFee = pools[_pid].tokenAmount * 2 * (100 - rewardMultiplier) / 100;
        polkaWarToken.transfer(msg.sender, award);
        polkaWarToken.transfer(owner(), gasFee);
        emit LogClaimAward(_pid, msg.sender, award);
        // initialize game
        pools[_pid].state = GameState.Opening;
        pools[_pid].winner = address(0);
        pools[_pid].player = new address[](0);
    }

    // withdraw funds
    function withdrawFund() external onlyOwner {
        uint256 balance = polkaWarToken.balanceOf(address(this));
        require(balance > 0, "not enough fund");
        polkaWarToken.transfer(msg.sender, balance);
    }
}