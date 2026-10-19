// Renders one SVG to PNG with resvg (decision 0205). Build-time tool only.
//
//   node tool/brand/resvg_render.js <in.svg> <out.png> <width-px>
//
// Needs `@resvg/resvg-js` on NODE_PATH, e.g.
//   npm i --prefix /tmp/resvg @resvg/resvg-js@2
//   NODE_PATH=/tmp/resvg/node_modules node tool/brand/resvg_render.js ...
const fs = require('fs');
const { Resvg } = require('@resvg/resvg-js');

const [, , input, output, width] = process.argv;
const resvg = new Resvg(fs.readFileSync(input), {
  fitTo: { mode: 'width', value: Number(width) },
  shapeRendering: 2, // geometricPrecision: anti-aliased edges
});
fs.writeFileSync(output, resvg.render().asPng());
