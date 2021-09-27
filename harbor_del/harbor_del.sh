#! /bin/bash
cd /home/lichao

set -e
HARBOR_URL=10.11.2.47
HARBOR_PASSWD=Harbor12345
OLD_VERSION_NUM=5
test_flag=0
function get_repos_list(){
    
  
  #repos_list:返回值为js格式，可以看到每一个仓库的portid等信息
  repos_list=$(curl -s -k -u admin:${HARBOR_PASSWD} http://${HARBOR_URL}/api/projects?page=1&page_size=50)
  mkdir -p $PWD/reposList
  echo "${repos_list}" | jq '.[]' | jq -r '.project_id' > $PWD/reposList/reposList.txt
  #把第一个命令作为第二个传入给下一个，获取 到有多少个镜像项目 1
}

function get_images_list(){
    
  mkdir -p $PWD/imagesList
  for repo in $(cat $PWD/reposList/reposList.txt);do

    #images_list：返回的是项目镜像里面的信息
    images_list=$(curl -s -k -u admin:${HARBOR_PASSWD} http://${HARBOR_URL}/api/repositories?project_id=${repo})
    echo "${images_list}" | jq '.[]' | jq -r '.name' > $PWD/imagesList/${repo}.txt
    #获取  每个项目下有多少个镜像 rancher/istio/examples-bookinfo-ratings-v1
  done
}

function delete_images(){
    


  #=====初始化====#
  rm -fr delete_images_tag
  mkdir -p delete_images_flag
  mkdir -p delete_images_tag
  len=0
  num=0
  num_delete_p_row=0
  num_p_row=0
  num_all_row=0
  images_name_flag=$1
  all_images_tag=() 
  test_flag=$[$test_flag+1]
  echo -e "\n \n第$test_flag镜像 ========== 执行镜像：  $images_name_flag =============="
  echo "第$test_flag镜像 ========== 执行镜像：  $images_name_flag =============="
  echo "第$test_flag镜像 ========== 执行镜像：  $images_name_flag =============="  
  #=====初始化====#

#读取harbor信息
#信息输出到 delete_images_flag/images-htmlinfo.txt上   
  htmlinfo=$(curl -s -k -u admin:${HARBOR_PASSWD} http://${HARBOR_URL}/api/repositories/$images_name_flag/tags)
  echo "${htmlinfo}" > $PWD/delete_images_flag/images-htmlinfo.txt

#打印镜像信息，tag,统计总行数num_all_row
#将tag打印到 delete_images_tag/no_arrange_tag_time.txt
#统计总行数num_all_row 大于设置值就不需要清理
  tag=$(echo "${htmlinfo}"  |jq '.[]' | jq -r '.name') 
  echo "${tag}" > $PWD/delete_images_tag/no_arrange_tag_time.txt
  num_all_row=$( sed -n '$=' $PWD/delete_images_tag/no_arrange_tag_time.txt)
  echo "=====tag总行数 num_all_row=$num_all_row======="
  if [[ "${num_all_row}" -lt "${OLD_VERSION_NUM}" ]]; then
    echo "$images_name_flag tag总行数小于设置值，不需要清理!!!"
    return
  fi


#打印的镜像排序，p-的不参与尽量，p-总行数num_delete_p_row
#将整理的 tag输出到  delete_images_tag/tag_time.txt，
   sort -n -k2 delete_images_tag/no_arrange_tag_time.txt |sed '/p-/d'  >   delete_images_tag/tag_time.txt

echo "=====================检测是否能执行================="
echo "=====================检测是否能执行================="
echo "=====================检测是否能执行================="
echo "=====================检测是否能执行================="
#检测tag_time.txt一共多少行，num_delete_p_row，减去保留行数，还多少
#如果小于0，则不需要删除
  num_delete_p_row=$( sed -n '$=' $PWD/delete_images_tag/tag_time.txt) 
  echo "=============$images_name_flag            num_delete_p_row=$num_delete_p_row          ==============="
  num=$[$num_delete_p_row - $OLD_VERSION_NUM]
  echo "=============$images_name_flag            num=$num          ==============="
  if [[ "${num}" -le "0" ]]; then   #判断是否大于 0
    echo "$images_name_flag has no need of cleanup!!!"
    return
  fi


#读取tag_time.txt数据，将数据存放在flag_i_row数组上
#数据存在在数组上，等待删除
  flag_i_row=0
  for i_row_tag in $(cat $PWD/delete_images_tag/tag_time.txt); do
    flag_i_row=$[$flag_i_row+1]
    all_images_tag[flag_i_row]="${i_row_tag}"
  done


 len=${#all_images_tag[@]}
 num=$[$len-$OLD_VERSION_NUM]
 echo  "*******   总镜像数量len=$len   需要删除镜像数量 num=$num   *******"

 echo -e "\n\n" >> $PWD/delete_images_tag.txt
  for index in $(seq 1 ${num}); do
    # tag=$(echo "${htmlinfo}" | jq ".[${index}]" | jq -r '.name')
     tag=${all_images_tag[index]}    
     echo "===需要删除的镜像 images=$images_name_flag   tag=${all_images_tag[index]}"
     echo "$images_name_flag:${all_images_tag[index]}" >> $PWD/delete_images_tag.txt
     #echo "images=$1 ************************** tag= ${tag}"  
    curl -s -k -u admin:${HARBOR_PASSWD} -X DELETE http://${HARBOR_URL}/api/repositories/$1/tags/${tag}
  done

  # if [[ test_flag -eq 100 ]]; then
  #   #statements
  #   exit 0
  # fi 


}


function clean_registry(){
    

  #image_name:goharbor/registry-photon:v2.6.2-v1.7.5
  image_name=$(docker ps | grep registry | grep photon | awk -F " " '{print $2}')
  echo "===========image_name===================="
  echo ${image_name}
  export gcdockername=`date +'gcdocker-%Y%m%d%H%M'`
  docker run -it --name $gcdockername --rm --volumes-from registry ${image_name} garbage-collect  /etc/registry/config.yml
}


function entrance(){
    
  serverip=`ip addr|grep inet|grep 10.11.2.47|grep -v inet6|awk '{print $2}'|cut -d/ -f1`
  #获取到serverip 是 ip：192.16.200.17
  # echo "${serverip}" > $PWD/test_serverip/images_serverip.txt
  
  #
  #检测输入url是否与服务器的url相等
  #
  if [[ "$serverip" != "${HARBOR_URL}" ]]; then
    echo "harbor is not running in the machine!!!"
    exit 1  
  fi

  # get_repos_list
  # 获取到harbor上有几个项目
  #返回值 reposList.txt--》 12345678
  get_repos_list

  #get_images_list
  #获取到项目里面的镜像
  #返回值  rancher/istio/examples-bookinfo-ratings-v1
  get_images_list

#for循环
#从项目1到项目7，检测每一个项目地下的镜像，例如for(i=0；i<8;i++){
    
#                                          for(j=0;j<镜像数量；j++) }
#
  #rm -fr delete_images_tag.txt
  for repo in $(cat $PWD/reposList/reposList.txt);do
    for images in $(cat $PWD/imagesList/${repo}.txt); do
      delete_images ${images}
    done
  done
  clean_registry
}
entrance
