require('onmt.init')

local tester = ...

local wordEmbeddingTest = torch.TestSuite()

function wordEmbeddingTest.default()
  local emb = onmt.WordEmbedding(10, 5)
  local input = torch.LongTensor({{1, 2}, {3, 4}, {5, 6}})
  local gradOutput = torch.Tensor(3, 2, 5):uniform()

  local output = emb:forward(input)
  tester:eq(output:size(), torch.LongStorage({3, 2, 5}))

  local gradInput = emb:backward(input, gradOutput)
  tester:eq(gradInput:size(), torch.LongStorage({3, 2}))
end


local function testFixedEmb(emb)
  tester:eq(emb:parameters(), nil)
  tester:eq(emb.net.gradWeight, nil)

  local weights = emb.net.weight:clone()

  local input = torch.LongTensor({{1, 2}, {3, 4}, {5, 6}})
  local gradOutput = torch.Tensor(3, 2, 5):uniform()

  local _ = emb:forward(input)
  local _ = emb:backward(input, gradOutput)

  tester:eq(emb.net.weight, weights)
end

function wordEmbeddingTest.fixedAtConstruction()
  local emb = onmt.WordEmbedding(10, 5, '', true)
  emb:postParametersInitialization()
  testFixedEmb(emb)
end

function wordEmbeddingTest.fixedToogled()
  local emb = onmt.WordEmbedding(10, 5)
  emb:postParametersInitialization()
  emb:fixEmbeddings(true)
  testFixedEmb(emb)
  emb:fixEmbeddings(false)
  tester:ne(emb.net.gradWeight, nil)
end

function wordEmbeddingTest.pretrained()
  local embs = torch.Tensor(10, 5):uniform()
  torch.save('embs.t7', embs)

  local emb = onmt.WordEmbedding(10, 5, 'embs.t7')
  emb:postParametersInitialization()

  tester:eq(emb.net.weight:narrow(1, 2, 9), embs:narrow(1, 2, 9))

  emb = onmt.WordEmbedding(10, 10, 'embs.t7')
  emb:postParametersInitialization()
  emb:fixEmbeddings('pretrained')

  tester:eq(emb.net.weight:narrow(1, 2, 9):narrow(2,1,5), embs:narrow(1, 2, 9))

  local t = torch.LongTensor{1,2,3}

  local output = emb:forward(t)
  output:uniform(0.1)
  emb:backward(t, output)

  tester:assertTensorEq(emb.net.gradWeight:narrow(2,1,5), torch.Tensor(10, 5):zero())
  tester:assertTensorNe(emb.net.gradWeight:narrow(2,6,5), torch.Tensor(10, 5):zero())

  os.remove('embs.t7')
end

return wordEmbeddingTest
