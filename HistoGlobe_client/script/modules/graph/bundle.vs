uniform vec3 color;

uniform float control_points[1000];
uniform vec3 line_begin;
uniform vec3 line_end;

//group:
uniform float group_offset;

//arc:
uniform float max_offset;
uniform vec3 line_center;

varying vec3 vColor;

// vec3 normalizedMercatusToLatLong(vec3 mercator){

//   float x = mercator.x * 360.0 - 180.0;
//   float y = (2.0 * atan(exp(mercator.y))-(0.5*3.14159265358979323846264)) * 180.0 - 90.0;
//   return vec3(x,y,1.0);

// }

vec3 LatLongToXYZ(vec3 LatLong){

  float x = 200.0 * cos(LatLong.x * 3.14159265358979323846264 / 180.0) * cos(-LatLong.y * 3.14159265358979323846264 / 180.0);
  float y = 200.0 * sin(LatLong.x * 3.14159265358979323846264 / 180.0);
  float z = 200.0 * cos(LatLong.x * 3.14159265358979323846264 / 180.0) * sin(-LatLong.y * 3.14159265358979323846264 / 180.0);
  return vec3(x,y,z);
}


void main() {

  vColor = color;

  // vec3 gps_point = normalizedMercatusToLatLong(position);
  // vec3 line_begin_latlng = normalizedMercatusToLatLong(line_begin);
  // vec3 line_end_latlng = normalizedMercatusToLatLong(line_end);
  // vec3 line_center_latlng = normalizedMercatusToLatLong(line_center);

  vec3 gps_point = vec3(position.x,position.y,1.0);

  if (max_offset == 0.0){

    float bundle_offset_lat = 0.0;
    float bundle_offset_lng = 0.0;            

    for(int i = 0 ; i < 1000; i+=4){

      if(control_points[i]<190.0){

        vec2 point_of_interest = vec2(control_points[i],control_points[i+1]);
        //vec2 dir = point_of_interest - gps_point.xy;
        vec2 dir = point_of_interest - position.xy;
        float dist = length(dir);
        float reach = control_points[i+2];

        if(dist <= reach){

          //vColor = vec3(0.5,0.0,0.0);

          dir = normalize(dir);

          vec2 distStart_vec = point_of_interest - vec2(line_begin.x,line_begin.y);
          float distStart = length(distStart_vec);
          vec2 distEnd_vec = point_of_interest - vec2(line_end.x,line_end.y);
          float distEnd = length(distEnd_vec);

          float strength = reach/2.0;
          //float strength = reach/3.14159265358979323846264;
          float power = 2.0;
           
          if(distStart > reach*0.75 && distEnd > reach*0.75){

              //vColor = vec3(0.0,0.5,0.0);
             
              float x_value = 1.0-(dist/reach);

              if(control_points[i+3] == 0.0){
                bundle_offset_lat += pow(sin(x_value*3.14159265358979323846264*0.5),power)*-1.0*dir.x*strength;
                bundle_offset_lng += pow(sin(x_value*3.14159265358979323846264*0.5),power)*-1.0*dir.y*strength;
              }
              else{
                bundle_offset_lat += pow(x_value,power)*-1.0*dir.x*strength;
                bundle_offset_lng += pow(x_value,power)*-1.0*dir.y*strength;
              }
          }
        }
      }
      else{
        break;
      }
    }

    gps_point.x += bundle_offset_lat;
    gps_point.y += bundle_offset_lng;
  }


  //group offset
  float dist1 = abs(length(gps_point-line_begin));
  float dist2 = abs(length(line_center-line_begin));
  vec3 ortho_dir = line_end - line_begin;
  ortho_dir = normalize(ortho_dir);
  float offset = 1.0 - pow((abs(dist2-dist1)/dist2),2.0);
  offset*= 0.1; // a tenth of a gps degree offset
  // offset in orthogonal direction to connection:
  gps_point.y += offset*group_offset*ortho_dir.y;
  gps_point.x += offset*group_offset*-ortho_dir.x;


  vec3 xyz = LatLongToXYZ(gps_point);

  //arc:
  vec3 line_center_xyz = LatLongToXYZ(vec3(line_center.x,line_center.y,1.0));
  vec3 line_begin_xyz = LatLongToXYZ(line_begin);
  vec3 line_end_xyz = LatLongToXYZ(line_end);
  
  float dist1_xyz = abs(length(line_center_xyz-xyz));
  float dist_begin_xyz = abs(length(line_center_xyz-line_begin_xyz));
  float dist_end_xyz = abs(length(line_center_xyz-line_end_xyz));
  float dist2_xyz = max(dist_begin_xyz,dist_end_xyz);
  if(abs(length(line_begin_xyz-xyz)) < abs(length(line_end_xyz-xyz))){
    dist2_xyz = dist_begin_xyz;
  }
  else{
    dist2_xyz =dist_end_xyz;
  }
  float factor = dist1_xyz/dist2_xyz;
  vec3 out_dir = -1.0 * normalize(vec3(0.0,0.0,0.0)-xyz);

  gl_Position = projectionMatrix * modelViewMatrix * vec4(xyz + ((1.0-pow(factor,2.0)) * max_offset * out_dir), 1.0);

}