"""Write a small Core ML linear embedding network.

The weights are a fixed normal draw. They are not trained on sentences.
The app uses this network as the local fallback. It is not all-MiniLM.
"""

from pathlib import Path

import numpy as np
from coremltools.models import MLModel, datatypes
from coremltools.models.neural_network import NeuralNetworkBuilder

rng = np.random.default_rng(20261013)
weight = rng.standard_normal((32, 64)).astype(np.float32) * 0.1
bias = np.zeros(32, dtype=np.float32)
builder = NeuralNetworkBuilder(
    input_features=[("tokens", datatypes.Array(64))],
    output_features=[("embedding", datatypes.Array(32))],
    disable_rank5_shape_mapping=True,
)
builder.add_inner_product(
    name="project",
    W=weight,
    b=bias,
    input_channels=64,
    output_channels=32,
    has_bias=True,
    input_name="tokens",
    output_name="embedding",
)
destination = Path(__file__).resolve().parents[1] / "Sources" / "AoriCore" / "Resources" / "aori-embed.mlmodel"
destination.parent.mkdir(parents=True, exist_ok=True)
MLModel(builder.spec).save(str(destination))
print(destination)
