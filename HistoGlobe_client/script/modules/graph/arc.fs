uniform float opacity;

varying vec3 vColor;

void main() {
  gl_FragColor     = vec4( 0.0,0.0,0.0, opacity );
  //gl_FragColor     = vec4( vColor.xyz, opacity );
}