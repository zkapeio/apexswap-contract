# @version >=0.3

MAX_SIZE: constant(uint256) = 1000

interface IERC721Metadata:
    def name() -> String[100]: view
    def symbol()-> String[100]: view
    def tokenURI(tokenId: uint256) -> String[300]: view
    def balanceOf(owner: address) -> uint256: view
    def ownerOf(tokenId: uint256) -> address: view
    def getApproved(tokenId: uint256) -> address: view
    def isApprovedForAll(owner: address, operator: address) -> bool: view
    def baseURI() -> String[300]: view
    def owner() -> address: view

interface IERC721Enumerable:
    def totalSupply() -> uint256: view
    def tokenOfOwnerByIndex(owner: address, index: uint256) -> uint256: view
    def tokenByIndex(index: uint256) -> uint256: view
    def supportsInterface(interfaceId: bytes4) -> bool: view

owner: public(address)

@external
def __init__():
    self.owner = msg.sender


@view
@external
def getContractInfo(_contract: address) -> (String[100], String[100], address, uint256):
    """
    get name, symbol, owner, totalsupply
    """
    _name: String[100] = IERC721Metadata(_contract).name()
    _symbol: String[100] = IERC721Metadata(_contract).symbol()
    _owner: address = IERC721Metadata(_contract).owner()
    _totalSupply: uint256 = IERC721Enumerable(_contract).totalSupply()

    return _name, _symbol, _owner, _totalSupply


@view
@external
def getAddressInfo(_contract: address, _sender: address) -> (uint256, DynArray[uint256, MAX_SIZE]):
    """
    get balance, tokenId
    """
    _balance: uint256 = IERC721Metadata(_contract).balanceOf(_sender)
    _tokenId: DynArray[uint256, MAX_SIZE] = []

    for i in range(MAX_SIZE):
        if i >= _balance:
            break
        else:
            _tid: uint256 = IERC721Enumerable(_contract).tokenOfOwnerByIndex(_sender, i)
            _tokenId.append(_tid)
    
    return _balance, _tokenId


@view
@external
def getTokenURI(_contract: address, _tokenId: uint256) -> String[300]:
    """
    get tokenURI
    """

    _tokenURI: String[300] = IERC721Metadata(_contract).tokenURI(_tokenId)
    return _tokenURI