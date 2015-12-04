uniform float max_offset;
uniform vec3 line_center;
uniform vec3 line_begin;
uniform vec3 line_end;

varying vec3 vColor;

void main() {
  float dist1 = abs(length(line_center-position));
  float dist_begin = abs(length(line_center-line_begin));
  float dist_end = abs(length(line_center-line_end));
  float dist2 = max(dist_begin,dist_end);
  
  if(abs(length(line_begin-position)) < abs(length(line_end-position))){
    dist2 = dist_begin;
  }
  else{
    dist2 =dist_end;
  }

  float factor = dist1/dist2;

  vec3 out_dir = -1.0 * normalize(vec3(0.0,0.0,0.0)-position);
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position + ((1.0-pow(factor,2.0)) * max_offset * out_dir), 1.0);

  if(dist1 <= dist2){
    vColor = vec3(0.0,1.0,0.0);
  }
  else{
    vColor = vec3(1.0,0.0,0.0);
  }
}