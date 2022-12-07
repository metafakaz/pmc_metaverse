/**
  *Submitted for verification at polygonscan.com on 2022-08-24
*/

// SPDX-License-Identifier: Apache-2.0
// Authors: six and Silur
pragma solidity ^0.8.16;

contract CCTF9 {
  address public admin;
  uint256 public volStart;
  uint256 public volMaxPoints;
  uint256 public powDiff;
  bool public started;

  uint256 public startTime;
  uint256 public endTime;

  uint256 public playerCount;
  uint256 public flagCount;

  uint8 constant public TIME_DECAY_MAX = 80;

  enum PlayerStatus {
    Unverified,
    Verified,
    Banned
  }

  enum FlagType {
    OnlyFirstSolver,
    Standard,
    CountDecay,
    TimeDecay
  }

  struct Player {
    PlayerStatus status;
    uint256 points; // 10000 = 1 point
    string name;
    uint256[2][] pointsPerFlag;
  }

  modifier onlyAdmin {
    require(msg.sender == admin, "Not admin");
    _;
  }

  modifier onlyActive {
    require(started == true, "CCTF not started.");
    require(block.timestamp >= startTime, "CCTF not started.");
    _;
  }

  modifier notExpired {
    require(endTime == 0 || block.timestamp <= endTime, "CCTF expired");
    _;
  }
 
  struct Flag {
    address signer;
    FlagType flagType;
    uint solveCount;
    uint256 points;
    uint256 currentPoints;
    string skill_name;
  }

  mapping (address => Player) public players;
  mapping (uint256 => Flag) public flags;

  address[] public playerList;
  uint256[] public flagList;

  event CCTFStarted(uint256 timestamp);
  event FlagAdded(uint256 indexed flagId, address flagSigner);
  event FlagRemoved(uint256 indexed flagId);
  event FlagSolved(uint256 indexed flagId, address indexed solver);
  event PlayerStatusChanged(address indexed player, PlayerStatus newStatus);

  constructor(uint256 _volMaxPoints, uint256 _powDiff) {
    admin = msg.sender;
    volMaxPoints = _volMaxPoints;
    powDiff = _powDiff;
    started = false;
  }

  function setAdmin(address _admin) external onlyAdmin {
    require(_admin != address(0));
    admin = _admin;
  }

  function setCCTFEndTime(uint256 _endTime) external onlyAdmin {
    require(endTime == 0 || block.timestamp < endTime, "CCTF expired");
    require(_endTime > block.timestamp, "End time is in the past");
    require(_endTime > startTime, "End time must be > start time");
    endTime = _endTime;
  }

  function setCCTFStartTime(uint256 _startTime) external onlyAdmin notExpired {
    require(endTime != 0, "Don't start before setting end time");
    require(startTime == 0 || startTime > block.timestamp, "Already started");
    require(_startTime >= block.timestamp, "Start time can't be in the past");
    started = true;
    startTime = _startTime;
  }

  function setCCTFPaused(bool _paused) external onlyAdmin notExpired {
    started = !_paused;
  }

  function setFlag(uint256 _flagId, address _flagSigner, FlagType _flagType, uint256 _points, string memory _skill) external onlyAdmin notExpired {
    if (flags[_flagId].signer == address(0)) {
      flagCount++;
      flagList.push(_flagId);
    }
    flags[_flagId] = Flag(_flagSigner, _flagType, 0, _points, 0, _skill);
    emit FlagAdded(_flagId, _flagSigner);
  }

  function setPowDiff(uint256 _powDiff) external onlyAdmin notExpired {
    powDiff = _powDiff;
  }

  function register(string memory _RTFM, string memory _name) external {
    require(players[msg.sender].status == PlayerStatus.Unverified, 'Already registered or banned');
    //uint256 pow = uint256(keccak256(abi.encodePacked("CCTF", msg.sender,"registration", nonce)));
    //require(pow < powDiff, "invalid pow");
    require(keccak256(abi.encodePacked('I_read_it')) == keccak256(abi.encodePacked(_RTFM)));  // PoW can be used for harder challenges, this is Entry!
    players[msg.sender].status = PlayerStatus.Verified;
    players[msg.sender].name = _name;
    playerList.push(msg.sender);
    playerCount++;
    emit PlayerStatusChanged(msg.sender, PlayerStatus.Verified);
  }

  function setPlayerStatus(address player, PlayerStatus status) external onlyAdmin notExpired {
    players[player].status = status;
    emit PlayerStatusChanged(player, status);
  }


////////// Submit flags
    mapping(bytes32 => bool) usedNs;                       // Against replay attack (we only check message signer)
    mapping (address => mapping (uint256 => bool)) Solves;     // address -> challenge ID -> solved/not
    uint256 public submission_success_count = 0;               // For statistics

    function SubmitFlag(bytes32 _message, bytes memory signature, uint256 _submitFor) external onlyActive notExpired {
        require(players[msg.sender].status == PlayerStatus.Verified, "You are not even playing");
        require(bytes32(_message).length <= 256, "Too long message.");
        require(!usedNs[_message]);
        usedNs[_message] = true;
// TODO commented out for the sake of the DEMO
        //require(recoverSigner(bytes32(abi.encodePacked(uint256(0), _message)), signature) == flags[_submitFor].signer, "Not signed with the correct key.");
        require(Solves[msg.sender][_submitFor] == false);

        Solves[msg.sender][_submitFor] = true;
        uint256 pointsGain = _getCurrentPoints(_submitFor);
        players[msg.sender].points += pointsGain;

        players[msg.sender].pointsPerFlag.push([_submitFor, pointsGain]);

        if (flags[_submitFor].flagType == FlagType.OnlyFirstSolver) {
            flags[_submitFor].points = 0;
        }

        players[msg.sender].points = players[msg.sender].points < volMaxPoints ? players[msg.sender].points : volMaxPoints;

        submission_success_count = submission_success_count + 1;
        flags[_submitFor].solveCount++;

        emit FlagSolved(_submitFor, msg.sender);
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig) public pure returns (bytes32 r, bytes32 s, uint8 v){
        require(sig.length == 65, "Invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

////////// Check status, scores, etc
  function getPlayerStatus(address _player) external view returns (PlayerStatus) {
    return players[_player].status;
  }

  function getPlayerPoints(address _player) external view returns (uint256) {
    return players[_player].points < volMaxPoints ? players[_player].points : volMaxPoints;
  } 

  function getSuccessfulSubmissionCount() external view returns (uint256){
      return submission_success_count;
  }

  function getPlayers() external view returns (Player[] memory playerListRet) {
    return getPlayers(0, playerCount);
  }

  function getPlayers(uint256 _idx, uint256 _count) public view returns (Player[] memory playerListRet) {
    if (_idx >= playerList.length) return playerListRet;
    if (playerList.length - _idx > _count) _count = playerList.length - _idx;
    playerListRet = new Player[](_count);
    for (uint256 i; i < _count; i++) {
      playerListRet[i] = players[playerList[_idx + i]];
    }
  }

  function getFlags() external view returns (Flag[] memory flagListRet) {
    return getFlags(0, flagCount);
  }

  function getFlags(uint256 _idx, uint256 _count) public view returns (Flag[] memory flagListRet) {
    if (_idx >= flagList.length) return flagListRet;
    if (flagList.length - _idx > _count) _count = flagList.length - _idx;
    flagListRet = new Flag[](_count);
    for (uint256 i; i < _count; i++) {
      flagListRet[i] = flags[flagList[_idx + i]];
      flagListRet[i].currentPoints = _getCurrentPoints(flagList[_idx + i]);
    }
  }

  function _getCurrentPoints(uint256 _flagId) internal view returns (uint256 currentPoints) {
        FlagType tmp = flags[_flagId].flagType;
        if (tmp == FlagType.OnlyFirstSolver || tmp == FlagType.Standard) currentPoints = flags[_flagId].points;
        else if (tmp == FlagType.CountDecay) currentPoints = flags[_flagId].points / (flags[_flagId].solveCount + 1);
        else if (tmp == FlagType.TimeDecay) {
          if (startTime == 0 || endTime == 0) return 0;
          uint256 _tst = block.timestamp;
          if (_tst < startTime) _tst = startTime;
          else if (_tst > endTime) _tst = endTime;
          currentPoints = (100 * (endTime - _tst) + TIME_DECAY_MAX * (_tst - startTime)) * flags[_flagId].points / ((endTime - startTime) * 100);
        }
  }
}
 